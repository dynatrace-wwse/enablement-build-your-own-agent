# Decisions — Build Your Own Observability Agent

The record for whoever runs this training next. Every question that shaped it is here: the options, what was chosen, why, and when. When a decision changes, add a new entry and mark the old one **superseded**. Do not edit the old entry.

Where things live:

- **How each exercise is checked, and the proof:** `VALIDATION.md`
- **The shared box and its data seeding:** `README.md` › Architecture, and D-12 below

| Id | Date | Decided by | Status |
|---|---|---|---|
| D-01 … D-08 | 2026-10-30 | owner (relayed by orch/main) | decided: the recommended option |
| D-09 | 2026-10-29 | owner (relayed by orch/main) | decided: fixed agenda |
| D-10, D-11 | 2026-10-29 | 210, agreed with 209 (contract v0.1) | decided |
| D-12 | 2026-10-30 | owner sets the goal, 210 the design | decided; the design is not yet run on a tenant |
| D-13 | 2026-10-30 | owner (via 209, contract v0.3) | decided |
| D-14 | 2026-11-03 | owner sets the goal, 210 the design | decided; not yet run on a box (staging is locked for the release) |
| D-15 | 2026-11-03 | owner, ENH-152 (via orch/main) | decided |

---

## D-01 · Can a custom agent be selected in the Run agent workflow action?

- **Question:** Part 2.3 runs the learner's own agent from a workflow, but the public docs list only the ready-made SRE Agent as selectable in **Run agent**.
- **Options:**
  - (a) Verify it on the Perform tenant before the event.
  - (b) Fallback: Run agent with the SRE Agent plus the learner's skill.
  - (c) Fallback: the "Prompt" agentic AI action, with the agent's instructions inline.
- **Chosen:** (a), with (b) written into 2.3 as the fallback.
- **Why:** 2.3 is the core of Part 2. (b) keeps the learner's skill in play, so the exercise still teaches grounding if custom agents cannot be selected.
- **Open action:** test it on the Perform tenant as soon as that tenant exists. Record the result in `VALIDATION.md` under 2.3.

## D-02 · Which tenant, and what AI request limit?

- **Question:** Forty learners running agents on schedules can throttle Assist for everyone on the tenant.
- **Options:**
  - (a) A dedicated Perform tenant, with a raised limit agreed with the CSM or PM.
  - (b) SRO as it is.
- **Chosen:** (a).
- **Why:** The run budget in 3.1 (at most 4 runs per hour per learner) lowers the risk but does not remove it. A shared limit hit mid-session stops the whole room.
- **Open action:** the trainer requests the tenant and the raised limit. The shared box then seeds that same tenant (D-13).

## D-03 · Learner IAM on the shared tenant

- **Question:** Learners must be able to create notebooks, dashboards, workflows, agents and skills, and read `dt.system.events` for their own checks.
- **Options:**
  - (a) One "workshop learner" policy per tenant.
  - (b) Broad user rights.
- **Chosen:** (a).
- **Why:** It is least privilege, and it can be reviewed once and reused for every run.
- **Open action:** write the policy (contract C-IAM in the README). It needs `storage:system:read` at minimum.

## D-04 · Ship the interim DQL checks now, or wait for `document-verification`?

- **Chosen:** ship them now.
- **Why:**
  - They work today, and all five were proven to parse on a tenant and to fail closed (`VALIDATION.md`).
  - Moving to `document-verification` later means swapping one block per step. Each step already carries a `PENDING_CHECK` for that swap.

## D-05 · Anti-copy in v1

- **Question:** The checks match the learner key in object names, so typing another learner's key can pass a check.
- **Options:**
  - (a) Accept this for Perform.
  - (b) Block until the owner check (C-IDENT) exists.
- **Chosen:** (a).
- **Why:** The stakes are low (no certificate hangs on it), and blocking would hold back the whole session.
- **Open action:** add the owner comparison when `{{DT_USER_EMAIL}}` and `{{DT_USER_ID}}` land. For workflows, join `WORKFLOW_CREATED.user.id`.

## D-06 · How is a learner's custom agent validated?

- **Question:** No supported API lists agents by name or owner.
- **Options:**
  - (a) Validate it through use: its workflow run in 2.3.
  - (b) Ask PM for a public listing API.
  - (c) Use the platform-reserved operator API.
- **Chosen:** (a) now and (b) in parallel. Not (c).
- **Why:** Reserved APIs change without notice, and the training must not break on Perform day.

## D-07 · Solutions for steps done in the UI (C-SOLVE)

- **Options:**
  - (a) A reveal-only `LAB_SOLUTION` counts as a solution in shared workshops. This needs a lint exception.
  - (b) A trainer-run automation creates the objects for a learner.
- **Chosen:** (a).
- **Why:** (b) needs a tenant identity per learner, which does not exist. Reveal text is what a learner can use with no terminal.
- **Effect:** the 6 `step-solution` lint warnings are accepted until the editor applies the exception.

## D-08 · Clean-up after the workshop

- **Options:**
  - (a) At teardown the platform sweeps learner objects by key, after the trainer confirms.
  - (b) Leave the objects for learners to keep.
- **Chosen:** (a), with an "export your notebook" note in 3.2.
- **Why:** A shared tenant fills up run after run. Learners who want their work can export it first.

## D-09 · Agenda and timings

- **Chosen:**
  - Intro 10 min
  - Part 1: 60 min
  - Break 5 min
  - Part 2: 70 min
  - Part 3: 30 min
  - Total 175 min.
- **Why:** Fixed by the owner. This is not open for change.

## D-10 · The learner key is `{{DT_SEED_SCOPE}}`, not `{{DT_SESSION_ID}}`

- **Why:**
  - `{{DT_SESSION_ID}}` ends in a UTC date, so it changes at midnight, which can fall in the middle of a workshop.
  - `{{DT_SEED_SCOPE}}` is the learner's e-mail local part, normalised and cut to at most 17 characters, with no date.
  - `byoaKey` in `my_functions.sh` computes the same string, and the tests pin that.

## D-11 · A DQL query proves itself with a column alias, not a comment

- **Why:** Proven on a tenant on 2026-10-29: `QUERY_EXECUTION_EVENT.query_string` masks comments and string literals to `*`, but keeps identifiers. A marker comment was never found; the alias `` `byoa_probe-q8` `` was found about 15 s after the query ran.

## D-12 · Shared box = data seeding with a Playground-like mix

- **Owner's goal (2026-10-30):**
  - The shared box exists to seed data into the trainer's tenant, so that not every learner needs their own processes.
  - The data should look like the Dynatrace Playground: several workloads with different problems (CPU, memory, a bit of everything).
- **Research:**
  - The internal search for the Playground's own data pipeline failed: Juno was unreachable (HTTP 540) on 2026-10-30. Agent 209 saw the same.
  - Re-check when Juno is back. Until then the design rests on what the framework ships.
  - The framework's astroshop is labelled "Demo.Live Astroshop", and its image comes from the demo-ability registry. It carries the OpenTelemetry demo's **flagd fault flags**: `adHighCpu`, `adManualGc`, `paymentFailure`, `kafkaQueueProblems`, `imageSlowLoad`, `loadgeneratorFloodHomepage` and others.
  - The Demo.Live helm variant also ships CronJobs that switch one flag on each hour from 07:00 to 17:00 and reset all flags every 30 minutes.
  - That rotation of built-in faults over continuously loaded apps is the pattern this box copies.
  - `deployAstroshop` in the framework turns those CronJobs off, so the BYOA box drives the flags itself.
- **Design (BYOA):**
  - Two clusters:
    - `byoa-shop`: astroshop
    - `byoa-ops`: easytrade, the todoapp, and a `chaos` namespace
  - One DynaKube per cluster.
  - Each app's own load generator runs all the time.
  - A problem generator rotates **11 faults** (14 since D-14). Each runs 20 min, then 5 min healed:

    | Kind | Faults |
    |---|---|
    | CPU | `adHighCpu` flag; container throttled at its limit (`cpuhog`) |
    | Memory | OOMKilled container (`memoryhog`); `adManualGc` flag |
    | Errors | `paymentFailure` flag; error-log burst |
    | Latency | `kafkaQueueProblems`, `imageSlowLoad` |
    | Traffic | homepage flood |
    | Availability | CrashLoopBackOff; easytrade database down |

  - One full cycle takes about 4.6 h. Over a 24 h lead every fault fires about five times, so Grail holds both open and closed problems of every kind when the class starts.
- **Not included, and why:** a host-level CPU or memory hog. Every cluster shares one machine, so saturating the host would slow the very box that serves the seed data. Container-level CPU throttling and OOM give Davis the same kinds of problem without that risk.
- **Status:**
  - Written, and unit-tested with a stubbed `kubectl` (`VALIDATION.md` › Box).
  - Not yet run on a real box: docker needs root on the dev host, and a live run needs the platform from ENH-146.

## D-13 · Shared box lifecycle (owner via 209, contract v0.3)

- **Scope:**
  - The shared box is bound to the trainer and seeds the trainer's tenant. That tenant is the workshop tenant.
  - Single-tenant only for now.
- **Timing:**
  - The box starts about 24 h before the class.
  - Its runtime is capped at 36 h unless the trainer schedules longer.
  - When the workshop ends, the box and every seat end together.
- **What this repo does about it:**
  - **The generator starts at create time, not at class time,** so Davis has a day of baseline and history.
  - **The generator caps itself:**
    - It heals every fault and exits after `BYOA_CHAOS_MAX_HOURS` (default 36).
    - This is a backstop for the platform's own cap.
  - **Tokens are re-read on every start:**
    - Tokens are not assumed to outlive 36 h.
    - `workshop-post-start.sh` re-reads the credentials on every start and re-applies each DynaKube, whose manifest carries the token secret.

## D-14 · More applications, running over time (extends D-12)

- **Owner's ask (2026-11-03):**
  - The shared box runs more applications over time, so the tenant holds more CPU, memory and other data.
  - That gives learners more to explore with Assist.
  - Research what the Playground runs and reuse what we can reach.
- **Research (internal sources, summarised):**
  - The Playground and its problem patterns belong to an internal demo team.
  - The applications that team names are a travel site, the trading app (easytrade) and a cluster workload simulator.
  - The travel site cannot run in containers and needs its own 6 GB VM.
  - The simulator is an internal load-test tool with no user interface, and it is not public.
  - The Playground's "live incident" demos are of the same kind as ours: a payment failure, an image-service slowdown, and disk and CPU problems.
  - The intentionally vulnerable social app (unguard) is public (dynatrace-oss) and runs on Dynatrace's own security demo clusters.
  - **Conclusion:** everything the Playground runs that we can reach is already a framework app.
- **What changed:**
  - **Apps**, three clusters, each with its own DynaKube:

    | Cluster | Apps |
    |---|---|
    | `shop` | astroshop and hipstershop (Online Boutique) |
    | `ops` | easytrade and the todoapp |
    | `sec` | unguard, with its malicious load generator on |

    Together they cover Java, Go, .NET, Node.js, Python, PHP and C++, with MariaDB, Postgres, Redis, RabbitMQ and Kafka.
  - **Traffic over time:**
    - A load shaper sets every load generator to a share of its peak once an hour.
    - It follows a 24-hour curve: 20 % at night, 100 % at midday.
    - It changes a generator only when the target changes, because a change restarts that pod.
    - Davis and Assist then see daily seasonality instead of flat lines.
  - **Faults:** 3 new ones, 14 in all:
    - hipstershop's currency service capped at 50 m CPU
    - unguard's database down
    - hipstershop's Redis cart store down
  - **Footprint log:**
    - Every hour, `~/.byoa-footprint.log` records CPU and memory per namespace and the host's free memory.
    - It is the headroom measurement for D-14's sizing.
  - **Token refresh:**
    - astroshop's OTel collector reads its own Secret (`dt-credentials`), which the framework's BUG-181 restart does not cover.
    - `byoaRefreshAstroshopSecret` rewrites that Secret and restarts the collector when the value changed.
    - A failed refresh fails `workshop-post-start.sh`.
- **Sizing, against the allowed shape (m6a.4xlarge, 16 vCPU / 64 GiB, $0.80/h):**
  - **Declared requests from the manifests and the chart:**

    | App | CPU | Memory |
    |---|---|---|
    | astroshop | 1.0 | 4.3 GiB (limits 4.9 CPU / 9.5 GiB) |
    | easytrade | 1.4 | 4.2 GiB |
    | hipstershop | 0.55 | 1.1 GiB |
    | unguard | 0.07 | 0.2 GiB, plus MariaDB |

  - **Measured in the sprint tenant, per cluster, average over 30 days:** Dynatrace 0.2 CPU / 2.6 GiB, the todoapp 0.1 / 1.5 GiB, ingress 1.0 GiB, kube-system 0.4 GiB.
  - Each of the three clusters carries its own Dynatrace, ingress and kube-system, which adds about 4 GiB per cluster.
  - **Estimate:**
    - Requests are about 4 CPU and 22 GiB.
    - At the noon peak, with every limit reached, the box would use about 9 CPU and 36 GiB.
    - Fault spikes come on top: `cpuhog` 0.2 CPU, the flood flag, and `memoryhog` up to 96 MiB.
    - This leaves about 40 % of the box's memory free, and room for a shared LLM only if it is small.
  - **The estimate was wrong (measured 2026-11-04, staging, 209):** the slot's memory limit is the host minus 4 GiB = 59,284 MiB, and it peaked at **58,563 MiB with 158 OOM kills**. All the kills were in the load generators: chrome 49, chrome_crashpad 19, node 8, locust 3, and Chrome's worker threads. None were in k3d, Kubernetes or the apps. The surge (+10 GiB in 2 min) came after the clusters were up, when the shaper set the noon peak.
  - **Why the estimate missed it:** astroshop runs `LOCUST_BROWSER_TRAFFIC_ENABLED=true`, so every Locust user drives a headless Chromium, and easytrade's `headlessloadgen` is Chrome too. The shaper raised those to 20 browser users and 3 Chrome generators (the framework default is 2 users and 1 generator).
  - **Fix (owner, 2026-11-04: "Do B, slim the load generator"):**
    - Peaks lowered to astroshop 6 browser users, hipstershop 10 HTTP users and easytrade 1 generator. The 24 h curve and the 14 faults are unchanged; only the intensity is lower.
    - Explicit memory requests and limits on the three generators (`BYOA_LOADGEN_LIMITS`).
    - A memory guard: below 14 GiB of slot headroom the shaper runs at half its curve value.
    - The footprint log records the slot's `memory.peak` and `oom_kill`.
    - Target, as changed after measuring: 0 OOM kills, anon + kernel ≤ 45 GiB, and no memory pressure. `memory.peak` cannot be the measure, because it counts the k3d nodes' image cache (about 37 GiB, reclaimable) and sits near the ceiling on any box this size. Result (R-11): anon + kernel 20.2 GiB at 100 % load, 0 kills, pressure 0.
  - A 4th app: anon + kernel leaves about 39 GiB of real headroom, so one more app fits by memory. The decision stays open, owner's call.
  - A bigger shape (r6a.4xlarge: 16 vCPU / 128 GiB) is an owner decision. It is not proposed yet.
- **Left out, and why:**
  - **The travel site:** not containerised, needs a 6 GB VM, internal.
  - **The workload simulator:** internal, and it produces load-test data rather than an application.
  - **gitlab:** heavy, and no observability story.
  - **ai-travel-advisor:** needs an LLM.
  - **opentelemetry-demo upstream:** duplicates astroshop.

## D-15 · Delivery declared: workshop-only, single tenancy (ENH-152)

- **Why:** a training with `.devcontainer/workshop-post-create.sh` must declare `delivery: {availability: workshop-only, tenancy: single}` in `docs/index.md`, or the framework's sync check refuses it.
- **Proof:** `sync check-delivery` at framework `d57abd3` passes (rc 0). With the block removed it fails (rc 1). See R-08.

## D-16 · Framework 1.20.3, image v1.4.0 (owner, 2026-11-04)

- **Owner:** "bump on PR branch, merge, book against main".
- **What:** `FRAMEWORK_VERSION` 1.18.0 → 1.20.3 in `.devcontainer/util/source_framework.sh`, and the image `shinojosa/dt-enablement` v1.3.2 → v1.4.0 in both places in `devcontainer.json`. v1.4.0 is the image framework 1.19 pinned; the repos already on 1.20.x use it.
- **Why 1.20.3:** BUG-181. A token refresh moves every DynaKube token reader onto the new tokens and waits for the restarts. A shared box depends on it, because `workshop-post-start.sh` re-runs `deployDynatrace` on a refresh. astroshop's own collector Secret stays this repo's job (`byoaRefreshAstroshopSecret`, BUG-185).
- **How:** a hand edit of the two pins. `sync push-update` only targets repos listed in `repos.yaml`, which this private repo is not; the test repo was bumped the same way. `devcontainer.json` is repo-owned, so a sync would not have moved the image anyway.
- **Repo-owned files from 1.18 to 1.20.3:** sync's migration changed none of the files this repo owns. The framework side adds the BUG-181 refresh, astroshop-lite, recognition of the shared-workshop scripts (ENH-146 F1), and helm 3.22.1.
- **Proof:** R-09.


## D-17 · Framework 1.22.0: the box registers its clusters itself (orch GO, 2026-11-06)

- **What:** `FRAMEWORK_VERSION` 1.20.3 → 1.22.0. The image stays v1.4.0 (1.22.0 pins the same).
- **Why:** BUG-199 (e), ENH-163 F13. A cluster appears in Dynatrace only once a `builtin:cloud.kubernetes` object carries its kube-system UID. The operator creates one only when its token has an effective `settings.write`, and skips it silently otherwise: the DynaKube then reads "kubernetesClusterMEID is outdated" and the cluster never shows up. That is the owner's COE run of 2026-11-06. From 1.22.0, `deployDynatrace` (which `byoaDeployDynatrace` calls once per cluster) finds or creates that object, labelled with the DynaKube name, and verifies the DynaKube reports its MEID.
- **Fatal here:** the shared box runs with `ORBITAL_SHARED_ROLE=shared`, so a cluster that cannot be registered fails the build, instead of a box reading READY while sending nothing. A seat (no shared role) gets a warning only.
- **Also in this jump:** framework 1.21.0 moved Dynatrace Operator 1.10.2 → 1.11.1 and checks the generated DynaKube before applying it (BUG-167).
- **Not yet:** removing the objects at teardown needs Orbital's pre-stop to call `frameworkTeardown` (follow-up). Until then, ending a workshop leaves its 3 objects in the tenant, as today.
- **How:** a hand edit of the pin, as in D-16 (this private repo is not in `repos.yaml`). No other repo was bumped (orch: the rest pick 1.22.0 up on their next normal sync).
- **Then 1.22.1 (2026-11-08):** R-14's negative control found that a registration failure on the READ returned rc 1 with no message, because the error went to stdout inside `$(…)`. On this box, where the failure is fatal, that would be a failed build with no reason. 1.22.1 (framework #224) prints it to stderr and names 401/403/404. The pin moved 1.22.0 → 1.22.1; the image is unchanged.
- **Proof:** R-14 (the run used 1.22.0; the 1.22.1 finder was checked live on the same boxes).
