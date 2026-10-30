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
  - A problem generator rotates **11 faults**. Each runs 20 min, then 5 min healed:

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
