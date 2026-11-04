#!/bin/bash
# SEAT mode — a classic per-learner environment. The workshop itself uses
# workshop-post-create.sh on a shared box; this script keeps the repo working on today's
# platform (one learner, one container) and in the nightly training test.
export SECONDS=0
source .devcontainer/util/source_framework.sh

setUpTerminal
installK9s
buildSeatEnvironment

finalizePostCreation
