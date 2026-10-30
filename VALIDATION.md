# Validation — Build Your Own Observability Agent

For every exercise, this file records:

- what the learner creates and what it must be called
- how the training checks it
- whether that check is **proven**, with the evidence

The run log at the bottom lists every verification ever run. Update this file with every change to a check or to the box. The decisions behind it are in `DECISIONS.md`.

`<key>` is `{{DT_SEED_SCOPE}}` (D-10). Marker means the column alias `` `byoa_<key>` `` (D-11).

## Exercises

| Step | Exercise | Object and name | Check (block in the page) | Live today | Proven | Evidence |
|---|---|---|---|---|---|---|
| intro | Welcome | — | `LAB_NO_SOLUTION` | — | — | — |
| 1.1 | Read the key and the rules | — | multiple-choice ×2 | ✅ | Y | lint and mkdocs green (R-03, R-04) |
| 1.1 | Teach Assist the runbook | KB skill `<key>-runbook`, stored as document `/skills/<key>-runbook/SKILL.md`, type `ai-agent-resource` | `PENDING_CHECK`: `document-verification` (contract C-DOC) | quiz only | partly | Type and name pattern seen for app-shipped skills on the sprint tenant (R-01). Not yet seen for a skill a user created. |
| 1.1 | Prompt Assist | `CoPilotConversation` document, prompt starts `<key>:` | `PENDING_CHECK`: `document-verification` | — | N | Can a learner list their own private conversations? Unproven. |
| 1.2 | Dashboard | `<key> · BYOA dashboard`, one tile query aliased with the marker | `dql-verification`: `dt.system.events` `QUERY_EXECUTION_EVENT`, `client.application_context == "dynatrace.dashboards"`, `query_string` contains the marker | ✅ | Y | Parses. The marker is found about 15 s after a run. The context value was seen in tenant data. Returns 0 for an unused key (R-01, R-02). |
| 1.2 | Notebook | `<key> · BYOA notebook`, one query aliased with the marker | same, any application context except dashboards and the Enablement app | ✅ | partly | Parses and fails closed (R-02). The notebooks context value has not been seen yet. |
| 1.2 | Page | `<key> · BYOA page` | `PENDING_CHECK`: `document-verification` | — | N | The Pages document type is unknown. |
| 1.3 | dtctl and MCP preview | — | multiple-choice | ✅ | Y | R-03 |
| 2.1 | Custom agent in Agent Studio | `<key>-triage-agent` | multiple-choice, then validated **through use** in 2.3 (D-06); `PENDING_CHECK` C-AGENT | quiz | N | No supported listing API (Juno, 2026-10-29). |
| 2.2 | Call the agent from Assist | conversation `<key>: @<key>-triage-agent …` | multiple-choice; `PENDING_CHECK` `CoPilotConversation` | quiz | N | as 1.1 Prompt |
| 2.3 | Run the agent from a workflow | workflow `<key> · BYOA triage` | `dql-verification`: `WORKFLOW_EVENT` `ACTION_EXECUTION`, title contains the key, `action.function == "run-agent"`, `state == "SUCCESS"` | ✅ | partly | Parses and fails closed (R-02). **The pass case has not been seen:** no run-agent run exists on the test tenant. Whether a *custom* agent can be selected is still open (D-01). |
| 2.3 | …on a schedule | same | `dql-verification`: `WORKFLOW_EXECUTION`, `trigger.type == "Schedule"` | ✅ | Y | `Schedule` and `Manual` were seen in tenant data (R-01). |
| 3.1 | Guardrail: run budget | same | `dql-verification`: 1 ≤ executions in the last hour ≤ 4, `within_budget == "yes"` | ✅ | Y | The logic was shown on a real workflow (R-02). |
| 3.1 | Guardrails and cost | — | multiple-choice | ✅ | Y | R-03 |
| 3.2 | Validate and roll out | — | multiple-choice and the scored assessment `build-your-own-agent-quiz` (3 questions, retake allowed) | ✅ | Y | R-03, R-04 |

Every `PENDING_CHECK` is a comment, so the importer ignores it. It becomes a `LAB_QUESTION` when its contract lands; swap it then and add a run below.

## The shared box (seeding, D-12 and D-13)

| What | How it is checked | Proven | Evidence |
|---|---|---|---|
| The key normalisation matches the app | bats `byoaKey …` | Y | R-05 |
| Cluster names end with the workshop id | bats `byoaClusterName …` | Y | R-05 |
| `DT_HOSTGROUP` is restored after each DynaKube deploy, even on failure | bats | Y | R-05; a mutation was caught (R-05) |
| The generator starts once, survives, stops, and ignores a stale pid | bats | Y | R-05 |
| Every fault has an inject and a heal branch | bats | Y | R-05, R-06 (a mutation was caught) |
| Every flag fault names a flag that the framework's astroshop defines | bats, against `$FRAMEWORK_DIR` | Y | R-06 (a mutated flag name was caught) |
| `byoaFlag` switches only that flag, on and off, then restarts flagd | bats with a stubbed `kubectl` | Y (logic) | R-06 (a mutation was caught) |
| The generator heals and exits at the 36 h cap | bats | Y | R-06 (removing the cap made the test hang and fail) |
| Davis opens a problem for each of the 11 faults | real box on a tenant | **N** | Needs the ENH-146 shared box. This is the first thing to run there. |
| A token refresh on restart reaches the DynaKubes | real box | **N** | as above |
| Two DynaKubes from one box in one tenant | real box | **N** | as above |
| `workshop-post-create.sh` end to end | real box | **N** | Docker needs root on the dev host, and the DT credentials cannot be read there by design |

## Verification runs

| Id | Date | What ran | Result |
|---|---|---|---|
| R-01 | 2026-10-29 | `dtctl` (sprint tenant, read-only): explored `dt.system.events` for `QUERY_EXECUTION_EVENT`, `WORKFLOW_EVENT` and `AUDIT_EVENT`, and documents of type `ai-agent-resource` | Comments and literals are masked, identifiers are kept. The workflow event types and the `trigger.type` values were seen. `AUDIT_EVENT/DOCUMENTS` carries no document names. |
| R-02 | 2026-10-29 | All 5 live `dql-verification` checks, with an unused key, plus the marker probe `` `byoa_probe-q8` `` | All parse. All return 0 or "no" for the unused key. The probe was found after about 15 s. |
| R-03 | 2026-10-29 | `tg lint` | 0 errors, 12 warnings, all accepted: 6 × `step-solution` (D-07), 5 × `dql-unscoped` (by design), 1 × first-step structure |
| R-04 | 2026-10-29 | `mkdocs build --strict` | green (`training_name` removed, as the starter documents) |
| R-05 | 2026-10-29 | `bats .devcontainer/test/shared-box.bats`: 9 tests. Mutation run: break the key cut, break the hostgroup restore | 9/9 pass. Each mutation failed its test. |
| R-06 | 2026-10-30 | Playground-like fault mix, `byoaFlag`, 36 h cap, token re-read in post-start. `bats` now has 12 tests. Mutations: a wrong flag name; `byoaFlag` that always sets `on`; the cap removed; a missing heal branch | 12/12 pass. Each mutation failed its test. The first `byoaFlag` test let the always-`on` mutation through, so an `off` assertion was added; the mutation is now caught. |
| R-07 | 2026-10-30 | Token refresh path, traced with 209 against fw `cff0018` and orbital `4f6c4bf`. A refreshed `.env` reaches `dynatraceEvalReadSaveCredentials` only when `.env` is re-sourced first and `DT_EVAL_SECRETS` is then unset. `variables.sh` sources `.env` without `set -a`. Local check: a variable new to `.env` reaches a child process after re-sourcing under `set -a` | `workshop-post-start.sh` now re-sources `.env` under `set -a` and then unsets `DT_EVAL_SECRETS`. The new variable reached the child. A trainer shell that is already open keeps the old tokens (209's A6 notes). |
