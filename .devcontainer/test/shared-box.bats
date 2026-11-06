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
  [ "$(byoaLoadTargets 100)" = "6 10 1" ]
  [ "$(byoaLoadTargets 50)" = "3 5 1" ]
  [ "$(byoaLoadTargets 1)" = "2 2 1" ]
}

@test "byoaApplyLoad changes the generators only when the targets change" {
  export CALLS="$BATS_TEST_TMPDIR/calls"
  kubectl() { echo "$*" >> "$CALLS"; }; export -f kubectl
  byoaApplyLoad 100
  [ "$(grep -c . "$CALLS")" -eq 3 ]
  grep -q "LOCUST_USERS=6" "$CALLS"
  grep -q " USERS=10" "$CALLS"
  grep -q "headlessloadgen --replicas=1" "$CALLS"
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

@test "the peaks stay inside the m6a.4xlarge budget (R-11): browser users and Chrome generators" {
  (( BYOA_PEAK_ASTRO_USERS <= 6 ))
  (( BYOA_PEAK_EASYTRADE_GENS <= 1 ))
  (( BYOA_PEAK_HIPSTER_USERS <= 10 ))
}

@test "every load generator gets a memory request and limit, and nothing else is touched" {
  export CALLS="$BATS_TEST_TMPDIR/calls"
  kubectl() { echo "$*" >> "$CALLS"; }; export -f kubectl
  byoaCapLoadGenerators
  [ "$(grep -c . "$CALLS")" -eq 3 ]
  grep -q "k3d-byoa-shop -n astroshop set resources deploy/load-generator --requests=memory=1Gi --limits=memory=3Gi" "$CALLS"
  grep -q "k3d-byoa-shop -n hipstershop set resources deploy/loadgenerator --requests=memory=128Mi --limits=memory=512Mi" "$CALLS"
  grep -q "k3d-byoa-ops -n easytrade set resources deploy/headlessloadgen --requests=memory=512Mi --limits=memory=1Gi" "$CALLS"
}

@test "a failed cap is reported, not swallowed" {
  kubectl() { return 1; }; export -f kubectl
  run byoaCapLoadGenerators
  [ "$status" -ne 0 ]
}

slot() {  # slot <current_mib> <max_mib|max> <peak_mib> <oom_kill>
  export BYOA_CGROUP_DIR="$BATS_TEST_TMPDIR/cg"; mkdir -p "$BYOA_CGROUP_DIR"
  echo $(( $1 * 1048576 )) > "$BYOA_CGROUP_DIR/memory.current"
  if [ "$2" = max ]; then echo max > "$BYOA_CGROUP_DIR/memory.max"; else echo $(( $2 * 1048576 )) > "$BYOA_CGROUP_DIR/memory.max"; fi
  echo $(( $3 * 1048576 )) > "$BYOA_CGROUP_DIR/memory.peak"
  printf 'low 0\nhigh 0\nmax 3\noom 2\noom_kill %s\n' "$4" > "$BYOA_CGROUP_DIR/memory.events"
}

@test "byoaSlotMem reads current, max, peak and oom_kill from the slot cgroup" {
  slot 30000 59284 31000 7
  [ "$(byoaSlotMem)" = "30000 59284 31000 7" ]
}

@test "byoaSlotMem says nothing when there is no cgroup to read" {
  export BYOA_CGROUP_DIR="$BATS_TEST_TMPDIR/none"
  run byoaSlotMem
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "the memory guard halves the load below the headroom floor and only then" {
  slot 30000 59284 31000 0
  [ "$(byoaLoadPercent 100 2>/dev/null)" = "100" ]
  slot 50000 59284 51000 0          # 9 GiB headroom < 14 GiB
  [ "$(byoaLoadPercent 100 2>/dev/null)" = "50" ]
  run byoaLoadPercent 100
  [[ "$output" == *"memory guard"* ]]
}

@test "without a readable cgroup the guard leaves the curve alone" {
  export BYOA_CGROUP_DIR="$BATS_TEST_TMPDIR/none"
  [ "$(byoaLoadPercent 85)" = "85" ]
}

@test "the footprint log carries the slot's peak and oom_kill" {
  slot 30000 59284 31000 4
  kubectl() { :; }; export -f kubectl
  export BYOA_FOOTPRINT_LOG="$BATS_TEST_TMPDIR/fp.log"
  byoaFootprint
  grep -q "slot mem_current=30000Mi mem_max=59284Mi mem_peak=31000Mi oom_kill=4" "$BYOA_FOOTPRINT_LOG"
}


@test "the hourly loop applies the load through the memory guard" {
  slot 50000 59284 51000 0
  export BYOA_FOOTPRINT_LOG="$BATS_TEST_TMPDIR/fp.log"
  kubectl() { :; }; export -f kubectl
  sleep() { exit 0; }               # one round, then out
  run byoaLoadLoop
  [[ "$output" == *"memory guard"* ]]
}

# ── ENH-163 F10: the app front on :80 ────────────────────────────────

_hosts_kubectl() {
  # Stub: shop declares two hosts, ops one, sec none; every controller has an LB address
  # unless NO_LB names the cluster.
  kubectl() {
    case "$*" in
      *"get svc ingress-nginx-controller"*) [[ "$2" == "k3d-byoa-${NO_LB:-none}" ]] || echo 172.18.0.2; return ;;
      *"get svc -A"*) return ;;
    esac
    case "$2" in
      k3d-byoa-shop) printf 'astroshop.1.2.3.4.sslip.io\nastroshop.box\n' ;;
      k3d-byoa-ops)  printf 'todoapp.1.2.3.4.sslip.io\n' ;;
      *) : ;;
    esac
  }
}

@test "byoaFrontConf routes each cluster's hosts to that cluster's LB port, 404 otherwise" {
  _hosts_kubectl
  run byoaFrontConf
  [ "$status" -eq 0 ]
  [[ "$output" == *"listen 80 default_server;"* ]]
  [[ "$output" == *"server_name astroshop.1.2.3.4.sslip.io astroshop.box;"* ]]
  [[ "$output" == *"proxy_pass http://127.0.0.1:30080;"* ]]
  [[ "$output" == *"server_name todoapp.1.2.3.4.sslip.io;"* ]]
  [[ "$output" == *"proxy_pass http://127.0.0.1:31080;"* ]]
  [[ "$output" != *"127.0.0.1:32080"* ]]          # sec declares no host: no server block
  [[ "$output" == *'proxy_set_header Host $host;'* ]]
}

@test "byoaFrontCheck fails when no cluster declares a host" {
  kubectl() { :; }
  run byoaFrontCheck
  [ "$status" -eq 1 ]
}

@test "byoaFrontCheck fails when an app does not answer through :80, passes when all do" {
  _hosts_kubectl
  curl() { echo 000; }
  run byoaFrontCheck
  [ "$status" -eq 1 ]
  curl() { case "$*" in *todoapp*) echo 502 ;; *) echo 200 ;; esac; }
  run byoaFrontCheck
  [ "$status" -eq 1 ]
  curl() { echo 200; }
  run byoaFrontCheck
  [ "$status" -eq 0 ]
}

@test "byoaStartFront copies the config in (never a bind mount) and starts the front" {
  _hosts_kubectl
  docker() { echo "$*" >> "$BATS_TEST_TMPDIR/docker"; }
  run byoaStartFront
  [ "$status" -eq 0 ]
  ! grep -q -- ' -v ' "$BATS_TEST_TMPDIR/docker"
  grep -q '^create --name byoa-front --restart unless-stopped --network host nginx' "$BATS_TEST_TMPDIR/docker"
  grep -q "^cp $BYOA_FRONT_CONF byoa-front:/etc/nginx/conf.d/default.conf" "$BATS_TEST_TMPDIR/docker"
  [ "$(tail -1 "$BATS_TEST_TMPDIR/docker")" = "start byoa-front" ]
}

@test "byoaStartFront fails when the copy fails" {
  _hosts_kubectl
  docker() { [ "$1" != cp ]; }
  run byoaStartFront
  [ "$status" -eq 1 ]
}

@test "byoaFrontCheck fails when a cluster's ingress controller has no LB address" {
  _hosts_kubectl
  curl() { echo 200; }
  NO_LB=ops run byoaFrontCheck
  [ "$status" -eq 1 ]
  [[ "$output" == *"byoa-ops: the ingress controller has no LoadBalancer address"* ]]
}

@test "byoaFrontCheck fails when a registered app's host has no Ingress (unguard.kube case)" {
  _hosts_kubectl
  curl() { echo 200; }
  export APP_REGISTRY="$BATS_TEST_TMPDIR/registry"
  echo "todoapp|todoapp|todoapp|8080|todoapp.1.2.3.4.sslip.io||todoapp--j" > "$APP_REGISTRY"
  run byoaFrontCheck
  [ "$status" -eq 0 ]
  echo "unguard|unguard|unguard-envoy-proxy|8080|unguard.1.2.3.4.sslip.io||unguard--j" >> "$APP_REGISTRY"
  run byoaFrontCheck
  [ "$status" -eq 1 ]
  [[ "$output" == *"app unguard: no Ingress declares unguard.1.2.3.4.sslip.io"* ]]
}

@test "byoaIngressOwnsLb turns every app LoadBalancer into ClusterIP, never the controller's" {
  kubectl() {
    case "$*" in
      *"get svc -A"*) printf 'hipstershop frontend-external LoadBalancer 10.0.0.1 172.18.0.2 80:1/TCP 1m\ningress-nginx ingress-nginx-controller LoadBalancer 10.0.0.2 <pending> 80:2/TCP 1m\nastroshop frontend ClusterIP 10.0.0.3 <none> 8080/TCP 1m\n' ;;
      *patch*) echo "$*" >> "$BATS_TEST_TMPDIR/patched" ;;
    esac
  }
  BYOA_LB_WAIT_S=0 byoaIngressOwnsLb shop
  [ "$(wc -l < "$BATS_TEST_TMPDIR/patched")" -eq 1 ]
  grep -q -- '-n hipstershop patch svc frontend-external' "$BATS_TEST_TMPDIR/patched"
}

# ── byoaDynakubeHealth (ENH-163 F13, BUG-199) ─────────────────────────
# kubectl is stubbed per cluster from files: $BATS_TEST_TMPDIR/<short>.dk (dynakube JSON) and
# <short>.log (operator log). Fixture lines are shaped like Dynatrace Operator 1.10.2's output.
dk_stub() {
  kubectl() {
    local ctx="" a; for a in "$@"; do [[ "$prev" == --context ]] && ctx="$a"; prev="$a"; done
    local short="${ctx#k3d-byoa-}"
    case "$*" in
      *"get dynakube"*) cat "$BATS_TEST_TMPDIR/$short.dk" 2>/dev/null ;;
      *"logs deploy/dynatrace-operator"*) cat "$BATS_TEST_TMPDIR/$short.log" 2>/dev/null ;;
    esac
  }
  export -f kubectl
}
dk_json() {  # <phase> <MonitoredEntity status> <reason>
  printf '{"items":[{"status":{"phase":"%s","conditions":[{"type":"Tokens","status":"True","reason":"TokenReady"},{"type":"MonitoredEntity","status":"%s","reason":"%s"}]}}]}' "$1" "$2" "$3"
}
OK_LINE='{"level":"info","msg":"finished DynaKube reconcile"}'
ERR_401='{"level":"error","msg":"Reconciler error","error":"get kubernetesClusterMEID: get k8s monitored entity: HTTP 401: Token Authentication failed"}'
ERR_OTHER='{"level":"error","msg":"Reconciler error","error":"HTTP 503: Service Unavailable"}'
healthy() { dk_json Running True StatusUpdated > "$BATS_TEST_TMPDIR/$1.dk"; echo "$OK_LINE" > "$BATS_TEST_TMPDIR/$1.log"; }

@test "dynakube health: three healthy clusters are ok" {
  dk_stub; healthy shop; healthy ops; healthy sec
  run byoaDynakubeHealth
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "shop ok Running" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "dynakube health: a revoked operator token (the F13 state) is token-rejected" {
  dk_stub; healthy shop; healthy ops
  dk_json Error False StatusOutdated > "$BATS_TEST_TMPDIR/sec.dk"
  printf '%s\n%s\n' "$OK_LINE" "$ERR_401" > "$BATS_TEST_TMPDIR/sec.log"
  run byoaDynakubeHealth
  [ "$status" -eq 1 ]
  [[ "${lines[2]}" == "sec token-rejected "* ]]
}

@test "dynakube health: old 401s followed by a finished reconcile (after Refresh) are ok" {
  dk_stub; healthy shop; healthy ops
  dk_json Running True StatusUpdated > "$BATS_TEST_TMPDIR/sec.dk"
  printf '%s\n%s\n%s\n' "$ERR_401" "$ERR_401" "$OK_LINE" > "$BATS_TEST_TMPDIR/sec.log"
  run byoaDynakubeHealth
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "sec ok Running" ]
}

@test "dynakube health: MEID outdated without a 401 in the log is still not ok" {
  dk_stub; healthy shop; healthy ops
  dk_json Running False StatusOutdated > "$BATS_TEST_TMPDIR/sec.dk"
  echo "$ERR_OTHER" > "$BATS_TEST_TMPDIR/sec.log"
  run byoaDynakubeHealth
  [ "$status" -eq 1 ]
  [[ "${lines[2]}" == "sec outdated "* ]]
}

@test "dynakube health: a missing DynaKube is reported, not skipped" {
  dk_stub; healthy shop; healthy sec
  run byoaDynakubeHealth
  [ "$status" -eq 1 ]
  [[ "${lines[1]}" == "ops missing "* ]]
}

@test "dynakube health: a non-401 reconcile error with phase Error is error, not token-rejected" {
  dk_stub; healthy shop; healthy ops
  dk_json Error True StatusUpdated > "$BATS_TEST_TMPDIR/sec.dk"
  echo "$ERR_OTHER" > "$BATS_TEST_TMPDIR/sec.log"
  run byoaDynakubeHealth
  [ "$status" -eq 1 ]
  [[ "${lines[2]}" == "sec error "* ]]
}

@test "trainingHealth is the Orbital poller's hook and reports what byoaDynakubeHealth reports" {
  dk_stub; healthy shop; healthy ops
  dk_json Error False StatusOutdated > "$BATS_TEST_TMPDIR/sec.dk"
  echo "$ERR_401" > "$BATS_TEST_TMPDIR/sec.log"
  run trainingHealth
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[2]}" == "sec token-rejected "* ]]
}
