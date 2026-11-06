#!/bin/bash
# Shared-infrastructure workshop: runs on EVERY start of the shared box.
# A stopped/started box comes back with its k3d clusters stopped and no background loops;
# this brings both back. Idempotent: running it on a healthy box changes nothing.
source .devcontainer/util/source_framework.sh

# Tokens may have been refreshed since the last start (contract v0.3: a box that runs past
# a token lifetime gets a fresh .env). Re-read them and re-apply each DynaKube, whose
# generated manifest carries the token secret; `kubectl apply` updates it in place.
# source_framework.sh has already sourced .env via variables.sh (values only); re-source it
# under `set -a` so a variable NEW to the refreshed file is exported to children too.
if [[ -f "${ENV_FILE:-}" ]]; then set -a; source "$ENV_FILE"; set +a; fi
unset DT_EVAL_SECRETS
dynatraceEvalReadSaveCredentials

dt_rc=0
for spec in "${BYOA_CLUSTERS[@]}"; do
  byoaUseCluster "${spec%%:*}"
  # framework >= 1.20.3: non-zero when a token reader did not finish restarting (BUG-181)
  byoaDeployDynatrace "${spec%%:*}" || dt_rc=$?
done

# astroshop's collector reads its own copy of the ingest token (not the DynaKube Secret, which
# deployDynatrace already handles): rewrite it and restart the collector when it changed.
byoaRefreshAstroshopSecret || { printError "astroshop dt-credentials refresh failed: its collector may hold the OLD ingest token"; dt_rc=1; }

byoaStartFront
startProblemGenerator
startTodoTraffic
startLoadShaper
checkSharedBoxReady
ready_rc=$?
# The worker records a token refresh as applied only on exit 0, so a refresh that left a
# reader on the old token must fail this script even when the box is otherwise ready.
if [[ "$dt_rc" -ne 0 ]]; then
  printError "Token refresh incomplete (rc=$dt_rc)"
  [[ "$ready_rc" -eq 0 ]] && ready_rc="$dt_rc"
fi
exit "$ready_rc"
