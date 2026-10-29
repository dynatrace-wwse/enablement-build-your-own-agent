# Build Your Own Observability Agent with Dynatrace

A Perform hands-on session (175 min): Assist and skills, custom agents built in Agent Studio, agentic workflows, and how to run them safely.

**Private repository.** It is delivered as a **shared-infrastructure workshop**: one machine and one tenant serve the trainer and every learner. That workshop type is being designed in the platform epic ENH-146. Until it lands, this repo also runs as a classic per-learner training (seat mode, see below).

| Part | Time | Pages |
|---|---|---|
| Intro | 10 min | `docs/index.md` |
| 1. Explore with Assist | 60 min | `1-1` Assist and skills · `1-2` notebooks, dashboards, Pages · `1-3` dtctl and MCP preview |
| Break | 5 min | |
| 2. Build your own agent | 70 min | `2-1` Agent Studio · `2-2` call it from Assist · `2-3` Run agent in a scheduled workflow |
| 3. Scale safely | 30 min | `3-1` guardrails and cost · `3-2` validate and roll out, plus the assessment |

## Architecture

```
            trainer (shell)                      learners (browser only, no terminal)
                 │                                        │
                 ▼                                        ▼
┌──────────── shared box (Sysbox) ───────────┐   ┌──────── ONE Dynatrace tenant ────────┐
│ workshop-post-create.sh  (once)            │   │ Assist · Knowledge Base · Agent Studio│
│ workshop-post-start.sh   (every start)     │   │ Notebooks · Dashboards · Pages        │
│                                            │   │ Workflows (Run agent action)          │
│ k3d byoa-shop  astroshop + DynaKube ───────┼──▶│                                       │
│ k3d byoa-ops   easytrade, todoapp,         │   │ every learner object carries the      │
│                chaos ns + DynaKube ────────┼──▶│ learner key {{DT_SEED_SCOPE}}         │
│ problem generator (detached loop):         │   └───────────────────────────────────────┘
│   crashloop → errorburst → memoryhog → dbdown, 20 min each, then heal
└────────────────────────────────────────────┘
```

- The box can be built **hours or days ahead**, so Grail already holds data and Davis has already opened problems when the workshop starts. Every script is idempotent and safe to restart.
- **Two clusters, one DynaKube each.** The framework names a DynaKube `<repo>-<getDtSessionId>`, and two clusters would collide on that name. `byoaDeployDynatrace` therefore makes the id per cluster for the duration of the call (`shop-<id>`, `ops-<id>`). This is a workaround until the framework takes a cluster name (ENH-146 phase 7).
- **Ports** are 30080/30443/6450 (shop) and 31080/31443/6451 (ops), so the box never competes with a host nginx for 80/443.
- **Problem generator.** `startProblemGenerator`/`stopProblemGenerator` in `.devcontainer/util/my_functions.sh` manage it: a pid file, a log at `~/.byoa-chaos.log`, the period set by `BYOA_CHAOS_PERIOD` (default 1200 s), and a heal step for every fault. Trainer check: `checkSharedBoxReady`.

### Seat mode (works today)

`post-create.sh` builds one k3d cluster with the todoapp and Dynatrace. That keeps the repo importable and testable on today's per-learner platform. The UI exercises are the same, and so are the checks.

## Naming convention: the learner key

| Object | Name |
|---|---|
| Notebook | `<key> · BYOA notebook` |
| Dashboard | `<key> · BYOA dashboard` |
| Page | `<key> · BYOA page` |
| Knowledge Base skill | `<key>-runbook` (stored as `/skills/<key>-runbook/SKILL.md`) |
| Custom agent | `<key>-triage-agent` |
| Workflow | `<key> · BYOA triage` |
| Assist prompts | start with `<key>:` |
| DQL marker | column alias `` `byoa_<key>` `` |

`<key>` is `{{DT_SEED_SCOPE}}`: the learner's e-mail local part, normalised and cut to at most 17 characters, with **no date**. `{{DT_SESSION_ID}}` is deliberately **not** used: its UTC date suffix changes at midnight, in the middle of a workshop. `byoaKey` in `my_functions.sh` reproduces the normalisation so tests can compute the same string.

**Why a column alias and not a comment.** Proven on a tenant on 2026-10-29: Grail's `QUERY_EXECUTION_EVENT.query_string` masks DQL comments **and** string literals to `*`. Identifiers survive verbatim, backticked ones included: `` `byoa_probe-q8` `` was found about 15 s after the query ran.

## Per-learner validation

| Step | Exercise | Object | How it is validated | Today | Proven |
|---|---|---|---|---|---|
| 1.1 | Teach Assist the runbook | KB skill `<key>-runbook` | `document-verification` `ai-agent-resource`, name starts `/skills/<key>-runbook/` | quiz only | type: Y for app-shipped skills, N for user-created |
| 1.1 | Prompt Assist | `CoPilotConversation` doc | `document-verification`, name starts `<key>:` | — | N: can a learner list own private conversations? |
| 1.2 | Dashboard | dashboard doc + its query | **today:** `dql-verification` on `QUERY_EXECUTION_EVENT`, `client.application_context == "dynatrace.dashboards"` and `query_string` contains `byoa_<key>` | ✅ | Y: query parses; marker pass and fail shown with a dtctl run; context value seen in tenant data |
| 1.2 | Notebook | notebook doc + its query | **today:** same, any app context except dashboards and the Enablement app | ✅ | partly: notebooks' context value not yet seen |
| 1.2 | Page | Pages doc | `document-verification` | — | N: Pages document type unknown |
| 2.1 | Agent in Agent Studio | agent `<key>-triage-agent` | `agent-verification` (name, owner, instructions, skills) | quiz; validated through use in 2.3 | N: no supported listing API found |
| 2.2 | Call agent from Assist | conversation | `document-verification` `CoPilotConversation` | quiz only | N |
| 2.3 | Run agent from a workflow | workflow `<key> · BYOA triage` | **today:** `dql-verification` on `WORKFLOW_EVENT` / `ACTION_EXECUTION`: title contains key, `action.function == "run-agent"`, `state == "SUCCESS"` | ✅ | parses and fails closed: Y; pass case: N (no run-agent run on the test tenant yet) |
| 2.3 | …on a schedule | same | **today:** `WORKFLOW_EXECUTION` with `trigger.type == "Schedule"` | ✅ | Y: the `Schedule` value was seen in tenant data |
| 3.1 | Guardrail: run budget | same | **today:** at least 1 and at most 4 executions in the last hour (`eq within_budget "yes"`) | ✅ | Y: parses; logic shown on a real workflow |
| 3.2 | Validate and roll out | — | quiz and the scored assessment | ✅ | — |

Checks that need platform work are written in the pages as `<!-- PENDING_CHECK … -->` comments. The importer ignores those, so they cannot be dropped silently or fail lint. Each one becomes a `LAB_QUESTION` when its contract lands.

**Anti-copy.** Today the checks match the key in the name. Anyone who types another learner's key can make that learner's check pass, or pass their own check with someone else's object. The planned fix compares the owner with the signed-in learner: `{{DT_USER_EMAIL}}` and `{{DT_USER_ID}}` (209, Q16). Workflows would join `WORKFLOW_CREATED.user.id`.

## Open platform contracts (with ENH-146 / agent 209)

| Id | Contract | Status |
|---|---|---|
| C-FILES | `.devcontainer/workshop-post-create.sh` runs once on the shared box, `workshop-post-start.sh` on every start; framework sync treats both as repo-owned | proposed by 209, written here |
| C-ENV | shared box env: `WORKSHOP_ROLE=shared`, `DT_WORKSHOP_ID=ws_…`, `DT_HOSTGROUP=ws-<hex>-<stamp>`, operator and ingest tokens only (no monaco or dtctl token) | proposed |
| C-ACCESS | learners have no seat and no terminal (`studentShell=0`, `personalSeats=0`); only the trainer can shell into the box | proposed |
| C-KEY | `{{DT_SEED_SCOPE}}` resolves for a learner who has no seat; a neutral alias `{{DT_USER_KEY}}` is proposed | resolves today (209); alias open |
| C-WSID | `{{DT_WORKSHOP_SESSION_ID}}`, the shared box's `DT_HOSTGROUP`, to scope data queries to this workshop's clusters | open; this repo does not use it yet |
| C-DOC | new `document-verification` question: `{docType, nameEquals or nameStartsWith, owner: self, contentContains[], since}`, run in the browser as the learner. Types needed: `notebook`, `dashboard`, `ai-agent-resource`, `CoPilotConversation`, Pages | open |
| C-AGENT | a way to verify a custom agent by name and owner: a supported listing API and its scope | open; owner question |
| C-IDENT | `{{DT_USER_EMAIL}}` and `{{DT_USER_ID}}` for anti-copy | open (Q16) |
| C-SOLVE | Steps done in the UI have no machine-runnable solution: a learner has no container, and a trainer's **Run solution** would need its own tenant identity to create objects for that learner. The editor counts a solution only when it has `commands`/`verify`, so it shows a `step-solution` warning on every UI step. Decide: reveal-only solutions count for shared workshops, or solutions get a way to run as the trainer against the tenant | open |
| C-IAM | learners can create notebooks, dashboards, workflows, agents and skills, and can read `dt.system.events` (`storage:system:read`) for their own checks | open; the owner question covers tenant IAM |

## What cannot be tested until the platform lands

- Building the shared box on Orbital (`workshop-post-create.sh` under `WORKSHOP_ROLE=shared`), and its restart path.
- Every `PENDING_CHECK`: documents, skills, conversations, Pages, agents.
- A real learner session with no seat, where `{{DT_SEED_SCOPE}}` resolves with no container behind it.
- Two DynaKubes in one tenant from one box, end to end (the scripts are written; they have not run against a tenant).
- The pass case of the Run agent check.

## Lint status

`tg lint` (the editor's own rules): **0 errors, 12 warnings**, all known and accepted for now:

- 6 × `step-solution`: UI steps carry a `LAB_SOLUTION` with only `reveal` text; see C-SOLVE.
- 5 × `dql-unscoped`: the checks are scoped by the learner key in the object name, not by `{{DT_SESSION_ID}}`. That is the point of the shared-workshop design (C-KEY); the rule assumes one cluster per learner.
- 1 × `step-structure-first-step`: the first step does not check what `post-create` built. In a shared workshop that is the trainer's job (`checkSharedBoxReady`), and checking it per learner needs C-WSID.

## Tests

```bash
bats .devcontainer/test/shared-box.bats   # helpers, no cluster needed (9 tests)
bash -n .devcontainer/*.sh .devcontainer/util/my_functions.sh
```

Each test was shown to fail on a broken helper (mutation run, 2026-10-29). `.devcontainer/test/integration.sh` is the seat-mode CI test.

Solutions use read-only queries only. A trainer's **Run solution** for a UI step has nothing to run: the solution is the `reveal` text. In the editor, every `dql-verification` draws on the app's per-tenant DQL budget (`takeDqlBudget` in the app's `api/_mint-budget.ts`), so do not press Test step in a loop.
