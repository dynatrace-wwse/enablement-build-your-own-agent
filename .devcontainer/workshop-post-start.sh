#!/bin/bash
# Shared-infrastructure workshop: runs on EVERY start of the shared box.
# A stopped/started box comes back with its k3d clusters stopped and no background loops;
# this brings both back. Idempotent: running it on a healthy box changes nothing.
source .devcontainer/util/source_framework.sh

for spec in "${BYOA_CLUSTERS[@]}"; do
  byoaUseCluster "${spec%%:*}"
done

startProblemGenerator
startTodoTraffic
checkSharedBoxReady
