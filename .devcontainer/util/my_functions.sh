#!/bin/bash
# ======================================================================
#          ------- Custom Functions -------                            #
#  Build Your Own Observability Agent — shared-infrastructure workshop #
#                                                                      #
#  Two ways this repo is built:                                        #
#   - SHARED BOX (the workshop): workshop-post-create.sh builds ONE    #
#     machine with several k3d clusters, several apps and a problem    #
#     generator. Every learner works in the SAME tenant, in the UI     #
#     only — no learner terminal. Only the trainer can shell in.       #
#   - SEAT (a classic per-learner environment): post-create.sh builds  #
#     a one-cluster version, so the repo still works on today's        #
#     platform and in the nightly training test.                       #
#                                                                      #
#  Rules (from the starter): `return`, never `exit`; idempotent;       #
#  a check returns 0 = pass; wait only when LAB_WAIT is set.           #
# ======================================================================

# ── Naming: one key per learner, one id per workshop ─────────────────
#
# Learner objects (notebooks, dashboards, skills, agents, workflows) are named with the
# learner KEY. In lesson Markdown the key is {{DT_SEED_SCOPE}}: the normalised e-mail local
# part, ≤17 chars, NO date (a date would change at UTC midnight mid-workshop). The shell has
# no learner — these helpers exist so tests and the trainer can compute the same strings.

# byoaKey <email-or-user> — the same normalisation as the app's computeDtSessionId without
# the date: lowercase, [^a-z0-9-] → "-", trim dashes, cut at 17, trim trailing dashes.
byoaKey() {
  local u="${1%%@*}"
  u="$(printf '%s' "$u" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')"
  u="${u:0:17}"
  while [[ "$u" == *- ]]; do u="${u%-}"; done
  printf '%s' "$u"
}

# byoaMarker <key> — the DQL field alias that proves a learner's query ran.
# Grail's query-execution events mask comments and string literals to "*", but keep
# identifiers verbatim — so the marker MUST be an alias, e.g.
#   | summarize byoa_alice_smith = count()
byoaMarker() {
  printf 'byoa_%s' "$(printf '%s' "$1" | tr '-' '_')"
}

# byoaClusterName <short> — k3d cluster name, and the k8s.cluster.name DynaKube reports.
# "<short>-<workshop id>". On the shared box the workshop id is DT_HOSTGROUP (209 contract:
# ws-<hex>-<stamp>); on a seat it is the learner's session id. Every cluster of one workshop
# therefore ENDS WITH the same id, so `endsWith(k8s.cluster.name, "<id>")` finds all of them.
byoaClusterName() {
  local short="$1"
  local id
  id="$(getDtSessionId 2>/dev/null)"
  if [[ -n "$id" ]]; then printf '%s-%s' "$short" "$id"; else printf '%s' "$short"; fi
}

# ── The shared box layout ────────────────────────────────────────────
#
#   cluster   short  apps                               host ports (http/https/api)
#   shop      shop   astroshop (OTel demo), hipstershop 30080 / 30443 / 6450
#   ops       ops    easytrade, todoapp, chaos          31080 / 31443 / 6451
#   sec       sec    unguard (+ its attack generator)   32080 / 32443 / 6452
#
# A Playground-like mix (DECISIONS.md D-12, D-14): web shops, a trading app, a CRUD service and an
# intentionally vulnerable social app, in Java, Go, .NET, Node.js, Python, PHP and C++, with
# MariaDB, Postgres, Redis, RabbitMQ and Kafka. Each app ships its own load generator.
#
# Ports avoid 80/443/6443 so the box never fights a host nginx (same reason Orbital's
# ops server uses 30080/30443/6444 — functions.sh createK3dCluster header).
BYOA_CLUSTERS=("shop:30080:30443:6450" "ops:31080:31443:6451" "sec:32080:32443:6452")

# byoaUseCluster <short> — create/attach the k3d cluster and make it the current context.
byoaUseCluster() {
  local short="$1" spec http https api
  for spec in "${BYOA_CLUSTERS[@]}"; do
    [[ "${spec%%:*}" == "$short" ]] || continue
    IFS=: read -r _ http https api <<<"$spec"
  done
  if [[ -z "$api" ]]; then printError "byoaUseCluster: unknown cluster '$short'"; return 1; fi
  export K3D_CLUSTER_NAME="byoa-${short}"
  export K3D_LB_HTTP_PORT="$http" K3D_LB_HTTPS_PORT="$https" K3D_API_PORT="$api"
  if k3d cluster list 2>/dev/null | grep -q "^${K3D_CLUSTER_NAME} "; then
    k3d cluster start "$K3D_CLUSTER_NAME" >/dev/null 2>&1 || true
    attachK3dCluster
  else
    createK3dCluster || return 1
  fi
  waitK3dApiReady
}

# byoaDeployDynatrace <short> — operator + one DynaKube in the CURRENT cluster.
# The framework names the DynaKube "<repo>-<getDtSessionId>" (generateDynakube); two clusters
# would collide on one name in Grail, so the id is made per cluster for the duration of the
# call. Workaround until the framework takes a cluster name (209 phase 7, functions.sh:2294).
byoaDeployDynatrace() {
  local short="$1" saved="${DT_HOSTGROUP:-}"
  local id; id="$(getDtSessionId 2>/dev/null)"
  export DT_HOSTGROUP="${short}${id:+-$id}"
  if ! helm status dynatrace-operator -n dynatrace >/dev/null 2>&1; then
    dynatraceDeployOperator || { DT_HOSTGROUP="$saved"; return 1; }
  fi
  deployDynatrace
  local rc=$?
  if [[ -n "$saved" ]]; then export DT_HOSTGROUP="$saved"; else unset DT_HOSTGROUP; fi
  return $rc
}

# ── Problem generator ────────────────────────────────────────────────
#
# A loop on the shared box that injects one fault at a time, so Davis opens real problems
# for learners to investigate and their agents to triage. It runs detached, writes a pid
# file and a log, and is (re)started by workshop-post-start.sh on every start.
BYOA_CHAOS_PID="${BYOA_CHAOS_PID:-$HOME/.byoa-chaos.pid}"
BYOA_CHAOS_LOG="${BYOA_CHAOS_LOG:-$HOME/.byoa-chaos.log}"
BYOA_CHAOS_PERIOD="${BYOA_CHAOS_PERIOD:-1200}"   # seconds per fault window (20 min)

BYOA_CHAOS_MAX_HOURS="${BYOA_CHAOS_MAX_HOURS:-36}"  # the loop heals and exits after this (the box cap)

# The faults, round-robin. Each is "<cluster> <name>" and has an inject and a heal step.
# The mix copies the Playground idea: services, containers and a database with CPU, memory,
# error, latency, traffic and availability problems. "flag:<name>" turns on one of
# astroshop's built-in fault flags (flagd); the others are pods in the `chaos` namespace or
# an easytrade change. Order alternates clusters and kinds so no two windows look alike.
BYOA_FAULTS=(
  "shop flag:adHighCpu"            # CPU: ad service burns CPU
  "ops crashloop"                  # availability: CrashLoopBackOff
  "shop flag:paymentFailure"       # errors: payment fails a share of requests
  "ops cpuhog"                     # CPU: container throttled at its limit
  "shop memoryhog"                 # memory: OOMKilled container
  "shop flag:kafkaQueueProblems"   # latency: queue lag between checkout and consumers
  "ops errorburst"                 # errors: error log burst
  "shop flag:adManualGc"           # memory: forced full GCs in the ad service
  "ops dbdown"                     # availability: easytrade database gone
  "shop flag:imageSlowLoad"        # latency: slow images behind the frontend proxy
  "shop flag:loadgeneratorFloodHomepage"  # traffic: request flood on the homepage
  "shop currencythrottle"          # CPU: hipstershop's currency service capped at 50m — checkout slows
  "sec unguarddbdown"              # availability: unguard's MariaDB gone — posts and logins fail
  "shop redisdown"                 # availability: hipstershop's cart store gone — cart errors
)

# byoaFlag <ctx> <flag> on|off — set a flag's defaultVariant in astroshop's flagd-config
# ConfigMap and restart flagd, whose init container copies the ConfigMap into its working file.
byoaFlag() {
  local ctx="$1" flag="$2" variant="$3" json
  json=$(kubectl --context "$ctx" -n astroshop get cm flagd-config -o jsonpath='{.data.demo\.flagd\.json}') || return 1
  json=$(jq -c --arg f "$flag" --arg v "$variant" '.flags[$f].defaultVariant = $v' <<<"$json") || return 1
  kubectl --context "$ctx" -n astroshop create cm flagd-config --from-literal=demo.flagd.json="$json" \
    --dry-run=client -o yaml | kubectl --context "$ctx" -n astroshop apply -f - >/dev/null || return 1
  kubectl --context "$ctx" -n astroshop rollout restart deploy flagd >/dev/null
}

byoaFaultInject() {
  local cluster="$1" fault="$2"
  local ctx="k3d-byoa-${cluster}"
  case "$fault" in
    flag:*)     byoaFlag "$ctx" "${fault#flag:}" on ;;
    currencythrottle)
      kubectl --context "$ctx" -n hipstershop set resources deploy currencyservice --limits=cpu=50m >/dev/null 2>&1 || true ;;
    unguarddbdown)
      kubectl --context "$ctx" -n unguard scale statefulset unguard-mariadb --replicas=0 >/dev/null 2>&1 || true ;;
    redisdown)
      kubectl --context "$ctx" -n hipstershop scale deploy redis-cart --replicas=0 >/dev/null 2>&1 || true ;;
    cpuhog)     # two busy loops under a 200m limit — the container is throttled all the time
      kubectl --context "$ctx" -n chaos create deploy pricing-worker --image=busybox:1.36 \
        -- sh -c 'yes >/dev/null & yes >/dev/null & wait' 2>/dev/null || true
      kubectl --context "$ctx" -n chaos set resources deploy pricing-worker --limits=cpu=200m >/dev/null 2>&1 || true ;;
    crashloop)  # a deployment whose container exits — CrashLoopBackOff, pod restarts
      kubectl --context "$ctx" -n chaos create deploy payment-retry --image=busybox:1.36 \
        -- sh -c 'echo "FATAL payment-retry: cannot reach ledger"; exit 1' 2>/dev/null || true ;;
    errorburst) # error logs at a steady rate, from a pod named like a real service
      kubectl --context "$ctx" -n chaos create deploy checkout-gateway --image=busybox:1.36 \
        -- sh -c 'while true; do echo "ERROR checkout-gateway: upstream timeout after 3000ms order=$RANDOM"; sleep 2; done' 2>/dev/null || true ;;
    memoryhog)  # a pod that grows past its limit — OOMKilled
      kubectl --context "$ctx" -n chaos apply -f - >/dev/null 2>&1 <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: recommendation-cache}
spec:
  replicas: 1
  selector: {matchLabels: {app: recommendation-cache}}
  template:
    metadata: {labels: {app: recommendation-cache}}
    spec:
      containers:
      - name: cache
        image: python:3.12-alpine
        command: ["python","-c","import time\nb=[]\nwhile True:\n  b.append(bytearray(8*1024*1024)); time.sleep(1)"]
        resources: {limits: {memory: 96Mi}}
EOF
      ;;
    dbdown)     # easytrade's database scaled to zero — trades fail, service errors rise
      kubectl --context "$ctx" -n easytrade scale deploy db --replicas=0 2>/dev/null || true ;;
  esac
}

byoaFaultHeal() {
  local cluster="$1" fault="$2"
  local ctx="k3d-byoa-${cluster}"
  case "$fault" in
    flag:*)     byoaFlag "$ctx" "${fault#flag:}" off ;;
    currencythrottle)  # the shipped manifest has no limits, so heal = remove them
      kubectl --context "$ctx" -n hipstershop patch deploy currencyservice --type=json \
        -p='[{"op":"remove","path":"/spec/template/spec/containers/0/resources/limits"}]' >/dev/null 2>&1 ;;
    unguarddbdown) kubectl --context "$ctx" -n unguard scale statefulset unguard-mariadb --replicas=1 >/dev/null 2>&1 ;;
    redisdown)  kubectl --context "$ctx" -n hipstershop scale deploy redis-cart --replicas=1 >/dev/null 2>&1 ;;
    cpuhog)     kubectl --context "$ctx" -n chaos delete deploy pricing-worker --ignore-not-found >/dev/null 2>&1 ;;
    crashloop)  kubectl --context "$ctx" -n chaos delete deploy payment-retry --ignore-not-found >/dev/null 2>&1 ;;
    errorburst) kubectl --context "$ctx" -n chaos delete deploy checkout-gateway --ignore-not-found >/dev/null 2>&1 ;;
    memoryhog)  kubectl --context "$ctx" -n chaos delete deploy recommendation-cache --ignore-not-found >/dev/null 2>&1 ;;
    dbdown)     kubectl --context "$ctx" -n easytrade scale deploy db --replicas=1 >/dev/null 2>&1 ;;
  esac
}

# The loop itself. Not called directly: startProblemGenerator runs it detached.
byoaChaosLoop() {
  local i=0 n=${#BYOA_FAULTS[@]} cluster fault
  local c
  for c in "${BYOA_CLUSTERS[@]}"; do
    kubectl --context "k3d-byoa-${c%%:*}" create ns chaos >/dev/null 2>&1 || true
  done
  local deadline=$(( $(date +%s) + BYOA_CHAOS_MAX_HOURS * 3600 ))
  while (( $(date +%s) < deadline )); do
    read -r cluster fault <<<"${BYOA_FAULTS[$((i % n))]}"
    echo "$(date -u +%FT%TZ) inject $cluster/$fault"
    byoaFaultInject "$cluster" "$fault"
    sleep "$BYOA_CHAOS_PERIOD"
    echo "$(date -u +%FT%TZ) heal   $cluster/$fault"
    byoaFaultHeal "$cluster" "$fault"
    sleep $((BYOA_CHAOS_PERIOD / 4))
    i=$((i + 1))
  done
  echo "$(date -u +%FT%TZ) stop   ${BYOA_CHAOS_MAX_HOURS}h cap reached"
}

isProblemGeneratorRunning() {
  [[ -f "$BYOA_CHAOS_PID" ]] && kill -0 "$(cat "$BYOA_CHAOS_PID" 2>/dev/null)" 2>/dev/null
}

# startProblemGenerator — idempotent: a running generator is left alone, a stale pid file
# is replaced. Detached with setsid so it survives the post-start shell.
startProblemGenerator() {
  if isProblemGeneratorRunning; then
    printInfo "Problem generator already running (pid $(cat "$BYOA_CHAOS_PID"))"
    return 0
  fi
  printInfoSection "Starting the problem generator (one fault every ${BYOA_CHAOS_PERIOD}s)"
  local self="${REPO_PATH}/.devcontainer/util/my_functions.sh"
  setsid bash -c "source '$self'; byoaChaosLoop" >>"$BYOA_CHAOS_LOG" 2>&1 < /dev/null &
  echo $! > "$BYOA_CHAOS_PID"
  sleep 1
  isProblemGeneratorRunning || { printError "Problem generator did not stay up — see $BYOA_CHAOS_LOG"; return 1; }
  printInfo "Problem generator pid $(cat "$BYOA_CHAOS_PID"), log $BYOA_CHAOS_LOG"
}

stopProblemGenerator() {
  if isProblemGeneratorRunning; then
    kill -- -"$(cat "$BYOA_CHAOS_PID")" 2>/dev/null || kill "$(cat "$BYOA_CHAOS_PID")" 2>/dev/null
  fi
  rm -f "$BYOA_CHAOS_PID"
  local f
  for f in "${BYOA_FAULTS[@]}"; do byoaFaultHeal ${f}; done
  printInfo "Problem generator stopped, all faults healed"
}

# ── Traffic ──────────────────────────────────────────────────────────
# easytrade and astroshop ship their own load generators (headlessloadgen / load-generator),
# so traffic needs nothing from us. The todoapp gets a light loop so its traces never go quiet.
startTodoTraffic() {
  local pidf="$HOME/.byoa-todo-traffic.pid"
  [[ -f "$pidf" ]] && kill -0 "$(cat "$pidf")" 2>/dev/null && return 0
  setsid bash -c 'while true; do
      kubectl --context k3d-byoa-ops -n todoapp run "traffic-$RANDOM" --rm -i --restart=Never --quiet \
        --image=curlimages/curl:8.10.1 -- curl -s -X POST "http://todoapp:8080/todos" \
        -H "Content-Type: application/json" -d "{\"title\":\"byoa $(date +%s)\"}" >/dev/null 2>&1
      sleep 30; done' >/dev/null 2>&1 < /dev/null &
  echo $! > "$pidf"
}

# ── Apps beyond the framework defaults ───────────────────────────────
# Idempotent wrappers: post-create may run again on a box that already has them.
byoaDeployHipsterShop() {
  kubectl get deploy frontend -n hipstershop >/dev/null 2>&1 || deployHipsterShop
}

# unguard with its malicious load generator on: attacks against itself, so the tenant holds
# vulnerabilities AND attack data (needs Application Security on the tenant to show them).
BYOA_UNGUARD_ATTACKS="${BYOA_UNGUARD_ATTACKS:-true}"
byoaDeployUnguard() {
  helm status unguard -n unguard >/dev/null 2>&1 || deployUnguard || return 1
  helm upgrade unguard oci://ghcr.io/dynatrace-oss/unguard/chart/unguard --version 0.12.0 -n unguard \
    --reuse-values --set maliciousLoadGenerator.enabled="$BYOA_UNGUARD_ATTACKS" >/dev/null
}

# ── Traffic over the day ─────────────────────────────────────────────
# Real systems are busy at noon and quiet at night; a flat load gives Davis and Assist flat
# lines. The shaper sets every load generator to a share of its peak once an hour, following
# BYOA_LOAD_CURVE (percent per UTC hour 0..23). It changes a generator only when its value
# changes, because each change restarts that generator's pod.
BYOA_LOAD_CURVE=(30 25 20 20 20 25 35 50 70 85 95 100 100 95 100 100 95 85 70 60 50 45 40 35)
BYOA_LOAD_PID="${BYOA_LOAD_PID:-$HOME/.byoa-load.pid}"
BYOA_LOAD_LOG="${BYOA_LOAD_LOG:-$HOME/.byoa-load.log}"
BYOA_LOAD_STATE="${BYOA_LOAD_STATE:-$HOME/.byoa-load.state}"
BYOA_PEAK_ASTRO_USERS="${BYOA_PEAK_ASTRO_USERS:-20}"
BYOA_PEAK_HIPSTER_USERS="${BYOA_PEAK_HIPSTER_USERS:-20}"
BYOA_PEAK_EASYTRADE_GENS="${BYOA_PEAK_EASYTRADE_GENS:-3}"

# byoaLoadTargets <percent> — "<astroshop users> <hipstershop users> <easytrade generators>", never 0
byoaLoadTargets() {
  local pct="$1" a h e
  a=$(( BYOA_PEAK_ASTRO_USERS * pct / 100 ));   (( a < 2 )) && a=2
  h=$(( BYOA_PEAK_HIPSTER_USERS * pct / 100 )); (( h < 2 )) && h=2
  e=$(( (BYOA_PEAK_EASYTRADE_GENS * pct + 50) / 100 )); (( e < 1 )) && e=1
  echo "$a $h $e"
}

byoaApplyLoad() {
  local pct="$1" targets last=""
  targets="$(byoaLoadTargets "$pct")"
  [[ -f "$BYOA_LOAD_STATE" ]] && last="$(cat "$BYOA_LOAD_STATE")"
  [[ "$targets" == "$last" ]] && return 0
  read -r a h e <<<"$targets"
  kubectl --context k3d-byoa-shop -n astroshop set env deploy/load-generator LOCUST_USERS="$a" >/dev/null 2>&1
  kubectl --context k3d-byoa-shop -n hipstershop set env deploy/loadgenerator USERS="$h" >/dev/null 2>&1
  kubectl --context k3d-byoa-ops -n easytrade scale deploy headlessloadgen --replicas="$e" >/dev/null 2>&1
  echo "$targets" > "$BYOA_LOAD_STATE"
  echo "$(date -u +%FT%TZ) load ${pct}%: astroshop users=$a hipstershop users=$h easytrade generators=$e"
}

# byoaLoadLoop — hourly: apply the curve, log the footprint. Heals to peak and exits at the cap.
byoaLoadLoop() {
  local deadline=$(( $(date +%s) + BYOA_CHAOS_MAX_HOURS * 3600 ))
  while (( $(date +%s) < deadline )); do
    byoaApplyLoad "${BYOA_LOAD_CURVE[$((10#$(date -u +%H)))]}"
    byoaFootprint
    sleep "${BYOA_LOAD_PERIOD:-3600}"
  done
  echo "$(date -u +%FT%TZ) stop   ${BYOA_CHAOS_MAX_HOURS}h cap reached"
}

isLoadShaperRunning() {
  [[ -f "$BYOA_LOAD_PID" ]] && kill -0 "$(cat "$BYOA_LOAD_PID" 2>/dev/null)" 2>/dev/null
}

startLoadShaper() {
  isLoadShaperRunning && return 0
  local self="${REPO_PATH}/.devcontainer/util/my_functions.sh"
  setsid bash -c "source '$self'; byoaLoadLoop" >>"$BYOA_LOAD_LOG" 2>&1 < /dev/null &
  echo $! > "$BYOA_LOAD_PID"
  sleep 1
  isLoadShaperRunning || { printError "Load shaper did not stay up — see $BYOA_LOAD_LOG"; return 1; }
  printInfo "Load shaper pid $(cat "$BYOA_LOAD_PID"), log $BYOA_LOAD_LOG"
}

stopLoadShaper() {
  isLoadShaperRunning && { kill -- -"$(cat "$BYOA_LOAD_PID")" 2>/dev/null || kill "$(cat "$BYOA_LOAD_PID")" 2>/dev/null; }
  rm -f "$BYOA_LOAD_PID" "$BYOA_LOAD_STATE"
}

# byoaFootprint — one line per namespace per cluster (CPU millicores, memory MiB) from
# metrics-server (k3s ships it), plus the host's free memory: the headroom record for sizing.
BYOA_FOOTPRINT_LOG="${BYOA_FOOTPRINT_LOG:-$HOME/.byoa-footprint.log}"
byoaFootprint() {
  local c short ts; ts="$(date -u +%FT%TZ)"
  for c in "${BYOA_CLUSTERS[@]}"; do
    short="${c%%:*}"
    kubectl --context "k3d-byoa-${short}" top pods -A --no-headers 2>/dev/null \
      | awk -v ts="$ts" -v cl="$short" '{cpu[$1]+=$3; mem[$1]+=$4}
          END {for (n in cpu) printf "%s %s %s cpu=%dm mem=%dMi\n", ts, cl, n, cpu[n], mem[n]}'
  done >> "$BYOA_FOOTPRINT_LOG"
  awk -v ts="$ts" '/MemTotal/{t=$2} /MemAvailable/{a=$2} END {printf "%s host mem_total=%dMi mem_available=%dMi\n", ts, t/1024, a/1024}' \
    /proc/meminfo >> "$BYOA_FOOTPRINT_LOG"
  echo "$ts host load=$(cut -d' ' -f1-3 /proc/loadavg) cpus=$(nproc)" >> "$BYOA_FOOTPRINT_LOG"
}

# ── App secrets that carry a Dynatrace token ─────────────────────────
# The framework restarts what reads the DynaKube's token Secret after a refresh (BUG-181), but
# astroshop's OTel collector reads its OWN Secret, dt-credentials, which deployAstroshop creates
# once. Rewrite it from the current tokens and restart its reader when the value changed.
byoaRefreshAstroshopSecret() {
  local ctx="k3d-byoa-shop" before after
  [[ -z "${DT_INGEST_TOKEN:-}" || -z "${DT_OTEL_ENDPOINT:-}" ]] && return 0
  before=$(kubectl --context "$ctx" -n astroshop get secret dt-credentials -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null)
  kubectl --context "$ctx" -n astroshop create secret generic dt-credentials \
    --from-literal="DT_API_TOKEN=$DT_INGEST_TOKEN" --from-literal="DT_ENDPOINT=$DT_OTEL_ENDPOINT" \
    --dry-run=client -o yaml | kubectl --context "$ctx" -n astroshop apply -f - >/dev/null || return 1
  after=$(kubectl --context "$ctx" -n astroshop get secret dt-credentials -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null)
  [[ "$before" == "$after" ]] && return 0
  printInfo "astroshop dt-credentials changed: restarting otel-collector"
  kubectl --context "$ctx" -n astroshop rollout restart deploy otel-collector >/dev/null \
    && kubectl --context "$ctx" -n astroshop rollout status deploy otel-collector --timeout=120s >/dev/null
}

# ── Trainer checks (the trainer's shell only; learners have none) ────
checkSharedBoxReady() {
  local c ok=0
  for c in "${BYOA_CLUSTERS[@]}"; do
    local short="${c%%:*}"
    if kubectl --context "k3d-byoa-${short}" get nodes --no-headers 2>/dev/null | grep -q " Ready"; then
      printInfo "cluster byoa-${short}: Ready"
    else
      printError "cluster byoa-${short}: not Ready"; ok=1
    fi
  done
  isProblemGeneratorRunning && printInfo "problem generator: running" || { printError "problem generator: NOT running"; ok=1; }
  isLoadShaperRunning && printInfo "load shaper: running" || { printError "load shaper: NOT running"; ok=1; }
  return $ok
}

# ── Seat mode (classic per-learner environment) ──────────────────────
# One cluster, the todoapp, Dynatrace. Keeps post-create.sh and the nightly training test
# working on today's platform; the UI exercises are identical.
buildSeatEnvironment() {
  startK3dCluster
  deployTodoApp
  dynatraceDeployOperator && deployDynatrace
  return 0
}
