#!/bin/bash
# Seat-mode integration test (CI and the nightly training test build post-create.sh, one cluster).
# The shared box has its own test: .devcontainer/test/shared-box.bats (no cluster needed) and
# checkSharedBoxReady on a real box.
source .devcontainer/util/source_framework.sh

printInfoSection "Running integration tests for $RepositoryName"
assertRunningPod todoapp todoapp
assertRunningApp todoapp
