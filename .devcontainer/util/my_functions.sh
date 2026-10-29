#!/bin/bash
# ======================================================================
#          ------- Custom Functions -------                            #
#  Your training-specific functions. This file is sourced into every   #
#  shell (Codespaces, Dev Containers and Orbital), so a function here  #
#  can be called from post-create.sh, from the terminal, from a        #
#  shell-verification `command:` and from a LAB_SOLUTION.              #
#                                                                      #
#  Write only what the framework lacks: it already ships checkNodeReady,#
#  checkTodoAppRunning, checkOperatorReady, checkDynakube,             #
#  checkOneAgentInjected, restartTodoApp, generateTodoTraffic and the  #
#  waitFor* helpers.                                                   #
#                                                                      #
#  Rules:                                                              #
#  - Use `return`, never `exit` — this file is sourced, not run.       #
#  - Use printInfoSection / printInfo / printError from the framework. #
#  - Keep functions idempotent — they may be called many times.        #
#  - A check returns 0 = pass. Probe once for a learner's click; wait  #
#    first only when LAB_WAIT is set (training test, Run solution).    #
# ======================================================================

# TODO(starter): replace this example with the checks and solution helpers your steps call.
# At least two todoapp pods are Running (step 2's check).
checkTodoAppScaled() {
  if [ -n "${LAB_WAIT:-}" ]; then
    local i=0
    while [ "$i" -lt 24 ]; do
      [ "$(kubectl get pods -n todoapp --no-headers 2>/dev/null | grep -c Running)" -ge 2 ] && break
      i=$((i + 1)); printInfo "fewer than 2 todoapp pods Running ($i/24), waiting 5s"; sleep 5
    done
  fi
  if [ "$(kubectl get pods -n todoapp --no-headers 2>/dev/null | grep -c Running)" -ge 2 ]; then
    printInfo "Two or more todoapp pods are Running"; return 0
  fi
  printError "Fewer than 2 todoapp pods are Running — scale the deployment to 2 replicas, wait for the new pod, then check again"; return 1
}
