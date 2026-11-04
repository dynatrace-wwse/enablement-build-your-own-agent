#!/bin/bash
# Shared-infrastructure workshop: runs ONCE on the shared box (209 contract: ORBITAL_SHARED_ROLE=shared).
# Builds every cluster, app and Dynatrace deployment the learners' tenant will see. The box may
# be built hours or days before the workshop, so the tenant already holds data and problems.
# Re-runnable: every step attaches to what exists instead of failing on it.
export SECONDS=0
source .devcontainer/util/source_framework.sh

setUpTerminal
installK9s

if [[ "${ORBITAL_SHARED_ROLE:-}" != "shared" ]]; then
  printWarn "ORBITAL_SHARED_ROLE is '${ORBITAL_SHARED_ROLE:-unset}', not 'shared' — building the shared box anyway (manual or local run)"
fi
printInfo "Workshop id: ${ORBITAL_WORKSHOP_ID:-<none>}  session id for cluster names: $(getDtSessionId)"

# Cluster 1 — "shop": the OpenTelemetry demo shop (traces and logs over OTLP) and the
# Online Boutique (hipstershop), traced by OneAgent.
byoaUseCluster shop
byoaDeployDynatrace shop
deployAstroshop
byoaDeployHipsterShop

# Cluster 2 — "ops": easytrade (has a DB we break), the todoapp, and the chaos namespace.
byoaUseCluster ops
byoaDeployDynatrace ops
deployEasyTrade
deployTodoApp

# Cluster 3 — "sec": unguard, an intentionally vulnerable social app, attacked by its own
# malicious load generator: vulnerabilities and attacks for Assist to explain.
byoaUseCluster sec
byoaDeployDynatrace sec
byoaDeployUnguard

# Faults, traffic and the day curve. workshop-post-start.sh restarts all three on every start;
# starting them here too means a box built a day ahead produces problems from the first hour.
startProblemGenerator
startTodoTraffic
startLoadShaper
byoaFootprint

checkSharedBoxReady
printInfo "Shared box built in ${SECONDS}s"
finalizePostCreation
