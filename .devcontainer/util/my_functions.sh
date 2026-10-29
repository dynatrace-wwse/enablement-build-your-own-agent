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
#   cluster   short  apps                          host ports (http/https/api)
#   shop      shop   astroshop (OTel demo)         30080 / 30443 / 6450
#   ops       ops    easytrade, todoapp, chaos     31080 / 31443 / 6451
#
# Ports avoid 80/443/6443 so the box never fights a host nginx (same reason Orbital's
# ops server uses 30080/30443/6444 — functions.sh createK3dCluster header).
BYOA_CLUSTERS=("shop:30080:30443:6450" "ops:31080:31443:6451")

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

# The faults, round-robin. Each is "<cluster> <name>" and has an inject and a heal step.
BYOA_FAULTS=("ops crashloop" "ops errorburst" "shop memoryhog" "ops dbdown")

byoaFaultInject() {
  local cluster="$1" fault="$2"
  local ctx="k3d-byoa-${cluster}"
  case "$fault" in
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
  while true; do
    read -r cluster fault <<<"${BYOA_FAULTS[$((i % n))]}"
    echo "$(date -u +%FT%TZ) inject $cluster/$fault"
    byoaFaultInject "$cluster" "$fault"
    sleep "$BYOA_CHAOS_PERIOD"
    echo "$(date -u +%FT%TZ) heal   $cluster/$fault"
    byoaFaultHeal "$cluster" "$fault"
    sleep $((BYOA_CHAOS_PERIOD / 4))
    i=$((i + 1))
  done
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
