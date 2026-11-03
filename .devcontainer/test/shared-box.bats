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
  run kill -0 "$pid"
  [ "$status" -ne 0 ]   # `! cmd` never fails a bats test (set -e ignores it)
  [ ! -f "$BYOA_CHAOS_PID" ]
}

@test "a stale pid file does not count as running" {
  echo 999999 > "$BYOA_CHAOS_PID"
  run isProblemGeneratorRunning
  [ "$status" -ne 0 ]   # `! cmd` never fails a bats test (set -e ignores it)
}

@test "every fault has an inject and a heal branch" {
  local f name
  for f in "${BYOA_FAULTS[@]}"; do
    name="${f#* }"
    [[ "$name" == flag:* ]] && name='flag:\*'
    [ "$(grep -c "^    ${name})" "$REPO_PATH/.devcontainer/util/my_functions.sh")" -eq 2 ]
  done
}

@test "every flag fault names a flag that astroshop's flagd config defines" {
  # FRAMEWORK_DIR: a codespaces-framework checkout (set on the dev box and in CI)
  local yaml="${FRAMEWORK_DIR:-/nonexistent}/.devcontainer/apps/astroshop/yaml/astroshop-deployment.yaml"
  [ -f "$yaml" ] || skip "FRAMEWORK_DIR not set to a codespaces-framework checkout"
  local f n=0
  for f in "${BYOA_FAULTS[@]}"; do
    [[ "${f#* }" == flag:* ]] || continue
    grep -q "^        \"${f#* flag:}\": {" "$yaml"
    n=$((n + 1))
  done
  [ "$n" -ge 1 ]
}

@test "byoaFlag sets only that flag's defaultVariant and restarts flagd" {
  export CALLS="$BATS_TEST_TMPDIR/calls"
  kubectl() {
    echo "$*" >> "$CALLS"
    case "$*" in
      *"get cm flagd-config"*) echo '{"flags":{"adHighCpu":{"defaultVariant":"off"},"cartFailure":{"defaultVariant":"off"}}}' ;;
      *"create cm flagd-config"*) echo "$*" > "$BATS_TEST_TMPDIR/created" ;;
    esac
  }
  export -f kubectl
  byoaFlag k3d-byoa-shop adHighCpu on
  grep -q '"adHighCpu":{"defaultVariant":"on"}' "$BATS_TEST_TMPDIR/created"
  grep -q '"cartFailure":{"defaultVariant":"off"}' "$BATS_TEST_TMPDIR/created"
  grep -q "rollout restart deploy flagd" "$CALLS"
  byoaFlag k3d-byoa-shop adHighCpu off
  grep -q '"adHighCpu":{"defaultVariant":"off"}' "$BATS_TEST_TMPDIR/created"
}

@test "the chaos loop stops and says so at the hour cap" {
  kubectl() { :; }; export -f kubectl
  BYOA_CHAOS_MAX_HOURS=0 run byoaChaosLoop
  [ "$status" -eq 0 ]
  [[ "$output" == *"cap reached"* ]]
  [[ "$output" != *"inject"* ]]
}

@test "the load curve covers 24 hours and peaks at 100" {
  [ "${#BYOA_LOAD_CURVE[@]}" -eq 24 ]
  local max=0 v
  for v in "${BYOA_LOAD_CURVE[@]}"; do (( v > max )) && max=$v; (( v >= 1 && v <= 100 )); done
  [ "$max" -eq 100 ]
}

@test "load targets scale with the curve and never reach zero" {
  [ "$(byoaLoadTargets 100)" = "20 20 3" ]
  [ "$(byoaLoadTargets 50)" = "10 10 2" ]
  [ "$(byoaLoadTargets 1)" = "2 2 1" ]
}

@test "byoaApplyLoad changes the generators only when the targets change" {
  export CALLS="$BATS_TEST_TMPDIR/calls"
  kubectl() { echo "$*" >> "$CALLS"; }; export -f kubectl
  byoaApplyLoad 100
  [ "$(grep -c . "$CALLS")" -eq 3 ]
  grep -q "LOCUST_USERS=20" "$CALLS"
  grep -q "USERS=20" "$CALLS"
  grep -q "headlessloadgen --replicas=3" "$CALLS"
  byoaApplyLoad 100            # same targets: no restart
  [ "$(grep -c . "$CALLS")" -eq 3 ]
  byoaApplyLoad 30
  [ "$(grep -c . "$CALLS")" -eq 6 ]
}

@test "the load shaper stops and says so at the hour cap" {
  kubectl() { :; }; export -f kubectl
  BYOA_CHAOS_MAX_HOURS=0 run byoaLoadLoop
  [ "$status" -eq 0 ]
  [[ "$output" == *"cap reached"* ]]
  [[ "$output" != *"load "*"%"* ]]
}

@test "every cluster has its own ports and api port" {
  local spec seen=" "
  for spec in "${BYOA_CLUSTERS[@]}"; do
    IFS=: read -r short http https api <<<"$spec"
    for p in "$http" "$https" "$api"; do [[ "$seen" != *" $p "* ]]; seen+="$p "; done
  done
  [ "${#BYOA_CLUSTERS[@]}" -eq 3 ]
}

@test "every fault targets a known cluster" {
  local f c known=" ${BYOA_CLUSTERS[*]%%:*} "
  for f in "${BYOA_FAULTS[@]}"; do c="${f%% *}"; [[ "$known" == *" $c "* ]]; done
}

@test "the astroshop secret refresh restarts the collector only when the secret changed" {
  export CALLS="$BATS_TEST_TMPDIR/calls" RV="$BATS_TEST_TMPDIR/rv"
  export DT_INGEST_TOKEN=x DT_OTEL_ENDPOINT=y
  echo 1 > "$RV"
  kubectl() {
    echo "$*" >> "$CALLS"
    case "$*" in
      *"get secret dt-credentials"*) cat "$RV" ;;
      *"apply -f -"*) cat >/dev/null; if [[ -f "$RV.bump" ]]; then echo 2 > "$RV"; fi ;;
      *"create secret"*) echo "kind: Secret" ;;
    esac
  }
  export -f kubectl
  byoaRefreshAstroshopSecret
  run grep -q "rollout restart" "$CALLS"
  [ "$status" -ne 0 ]   # `! cmd` never fails a bats test (set -e ignores it)
  touch "$RV.bump"
  byoaRefreshAstroshopSecret
  grep -q "rollout restart deploy otel-collector" "$CALLS"
}
