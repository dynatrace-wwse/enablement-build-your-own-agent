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

for spec in "${BYOA_CLUSTERS[@]}"; do
  byoaUseCluster "${spec%%:*}"
  byoaDeployDynatrace "${spec%%:*}"
done

startProblemGenerator
startTodoTraffic
checkSharedBoxReady
