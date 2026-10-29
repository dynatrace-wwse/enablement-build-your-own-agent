#!/usr/bin/env bats
# Unit tests for the shared-box helpers. No cluster, no tenant: kubectl/k3d/getDtSessionId are
# stubbed, so these run anywhere bats does.

setup() {
  export HOME="$BATS_TEST_TMPDIR"
  export REPO_PATH="$BATS_TEST_DIRNAME/../.."
  printInfo() { :; }; printError() { echo "ERR $*" >&2; }; printInfoSection() { :; }; printWarn() { :; }
  export -f printInfo printError printInfoSection printWarn
  source "$REPO_PATH/.devcontainer/util/my_functions.sh"
}

@test "byoaKey matches the app's normalisation (no date)" {
  [ "$(byoaKey Alice.Smith@example.com)" = "alice-smith" ]
  [ "$(byoaKey 'x__y--')" = "x-y" ]
  [ "$(byoaKey abcdefghijklmnop-qrstuvwxyz@x)" = "abcdefghijklmnop" ]   # cut at 17, trailing dash trimmed
}

@test "byoaMarker turns dashes into underscores" {
  [ "$(byoaMarker alice-smith)" = "byoa_alice_smith" ]
}

@test "byoaClusterName ends with the workshop id, so endsWith finds every cluster" {
  getDtSessionId() { echo "ws-ab12-1030"; }
  [ "$(byoaClusterName shop)" = "shop-ws-ab12-1030" ]
  [ "$(byoaClusterName ops)" = "ops-ws-ab12-1030" ]
}

@test "byoaClusterName without an id is just the short name" {
  getDtSessionId() { echo ""; }
  [ "$(byoaClusterName shop)" = "shop" ]
}

@test "byoaUseCluster refuses an unknown cluster" {
  run byoaUseCluster nope
  [ "$status" -eq 1 ]
}

@test "byoaDeployDynatrace restores DT_HOSTGROUP after the call, even on failure" {
  getDtSessionId() { echo "${DT_HOSTGROUP:-}"; }
  helm() { return 0; }
  deployDynatrace() { echo "dk:$DT_HOSTGROUP" > "$BATS_TEST_TMPDIR/seen"; return 3; }
  export DT_HOSTGROUP="ws-ab12-1030"
  run byoaDeployDynatrace shop
  [ "$status" -eq 3 ]
  [ "$(cat "$BATS_TEST_TMPDIR/seen")" = "dk:shop-ws-ab12-1030" ]
  byoaDeployDynatrace shop || true
  [ "$DT_HOSTGROUP" = "ws-ab12-1030" ]
}

@test "the problem generator starts once, survives, and stops" {
  export BYOA_CHAOS_PERIOD=3600
  kubectl() { :; }; export -f kubectl
  # run the real loop body detached against the stubbed kubectl
  startProblemGenerator
  local pid; pid="$(cat "$BYOA_CHAOS_PID")"
  kill -0 "$pid"
  startProblemGenerator                      # idempotent: same pid
  [ "$(cat "$BYOA_CHAOS_PID")" = "$pid" ]
  stopProblemGenerator
  ! kill -0 "$pid" 2>/dev/null
  [ ! -f "$BYOA_CHAOS_PID" ]
}

@test "a stale pid file does not count as running" {
  echo 999999 > "$BYOA_CHAOS_PID"
  ! isProblemGeneratorRunning
}

@test "every fault has an inject and a heal branch" {
  local f name
  for f in "${BYOA_FAULTS[@]}"; do
    name="${f#* }"
    grep -q "^    ${name})" "$REPO_PATH/.devcontainer/util/my_functions.sh"
    [ "$(grep -c "^    ${name})" "$REPO_PATH/.devcontainer/util/my_functions.sh")" -eq 2 ]
  done
}
