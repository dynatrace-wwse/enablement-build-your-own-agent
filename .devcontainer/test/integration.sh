#!/bin/bash
# Load framework
source .devcontainer/util/source_framework.sh

printInfoSection "Running integration Tests for $RepositoryName"

#TODO: In here you add your assertions
#assertRunningPod dynatrace operator

#assertRunningPod dynatrace activegate

#assertRunningPod dynatrace oneagent

assertRunningPod todoapp todoapp

assertRunningApp todoapp

# TODO(starter): replace with your own steps' fail-first proof, or delete with step 2.
# Step 2's check must FAIL before its solution and PASS after it — a check that cannot fail proves nothing.
if checkTodoAppScaled; then
  printError "checkTodoAppScaled passed before the step's solution ran — the check cannot fail"
  exit 1
fi
kubectl scale deployment todoapp -n todoapp --replicas=2
LAB_WAIT=1 checkTodoAppScaled || exit 1
