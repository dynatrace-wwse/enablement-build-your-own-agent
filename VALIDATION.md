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
| The load curve has 24 hours and peaks at 100; targets never reach 0 | bats | Y | R-08 |
| The load shaper restarts a generator only when its target changes, and stops at the cap | bats | Y | R-08 (a mutation was caught) |
| Every cluster has its own ports, and every fault targets a known cluster | bats | Y | R-08 (a mutation was caught) |
| astroshop's own token Secret is rewritten, and the collector restarts only when the Secret changed | bats with a stubbed `kubectl` | Y (logic) | R-08 (a mutation was caught) |
| `delivery` front matter accepted by the framework (ENH-152) | `sync check-delivery` | Y | R-08 |
| Davis opens a problem for each of the 14 faults | real box on a tenant | **N** | Needs the ENH-146 shared box. This is the first thing to run there. |
| The box fits m6a.4xlarge at peak load (`~/.byoa-footprint.log`) | real box | **N** | D-14 estimate: about 9 CPU and 36 GiB at peak |
| hipstershop and unguard deploy beside astroshop and easytrade, three DynaKubes in one tenant | real box | **N** | as above |
| A token refresh on restart reaches the DynaKubes | real box | **Y** | R-13: all 3 Secrets and `.env` on one new token pair after Refresh tokens (hash compare) |
| A dead operator token (revoked/expired) fails `checkSharedBoxReady` per cluster; old 401s before a finished reconcile do not | bats with a stubbed `kubectl` (`byoaDynakubeHealth`) | Y (logic) | R-13 (two mutations caught) |
| Three DynaKubes from one box, three distinct MEIDs, data from all three | real box | Y | R-13 |
| Two DynaKubes from one box in one tenant | real box | **N** | as above |
| `workshop-post-create.sh` end to end | real box | **N** | Docker needs root on the dev host, and the DT credentials cannot be read there by design |

## Verification runs

| Id | Date | What ran | Result |
|---|---|---|---|
| R-01 | 2026-10-29 | `dtctl` (sprint tenant, read-only): explored `dt.system.events` for `QUERY_EXECUTION_EVENT`, `WORKFLOW_EVENT` and `AUDIT_EVENT`, and documents of type `ai-agent-resource` | Comments and literals are masked, identifiers are kept. The workflow event types and the `trigger.type` values were seen. `AUDIT_EVENT/DOCUMENTS` carries no document names. |
| R-02 | 2026-10-29 | All 5 live `dql-verification` checks, with an unused key, plus the marker probe `` `byoa_probe-q8` `` | All parse. All return 0 or "no" for the unused key. The probe was found after about 15 s. |
| R-03 | 2026-10-29 | `tg lint` | 0 errors, 12 warnings, all accepted: 6 × `step-solution` (D-07), 5 × `dql-unscoped` (by design), 1 × first-step structure |
| R-04 | 2026-10-29 | `mkdocs build --strict` | green. **Corrected 2026-11-04 (R-09):** `training_name` was never removed — Orbital's catalog reads it, and `mkdocs.yaml` notes that mkdocs warns about it. `--strict` turns that one warning into a failure, on `main` too; CI builds without `--strict`. |
| R-05 | 2026-10-29 | `bats .devcontainer/test/shared-box.bats`: 9 tests. Mutation run: break the key cut, break the hostgroup restore | 9/9 pass. Each mutation failed its test. |
| R-06 | 2026-10-30 | Playground-like fault mix, `byoaFlag`, 36 h cap, token re-read in post-start. `bats` now has 12 tests. Mutations: a wrong flag name; `byoaFlag` that always sets `on`; the cap removed; a missing heal branch | 12/12 pass. Each mutation failed its test. The first `byoaFlag` test let the always-`on` mutation through, so an `off` assertion was added; the mutation is now caught. |
| R-07 | 2026-10-30 | Token refresh path, traced with 209 against fw `cff0018` and orbital `4f6c4bf`. A refreshed `.env` reaches `dynatraceEvalReadSaveCredentials` only when `.env` is re-sourced first and `DT_EVAL_SECRETS` is then unset. `variables.sh` sources `.env` without `set -a`. Local check: a variable new to `.env` reaches a child process after re-sourcing under `set -a` | `workshop-post-start.sh` now re-sources `.env` under `set -a` and then unsets `DT_EVAL_SECRETS`. The new variable reached the child. A trainer shell that is already open keeps the old tokens (209's A6 notes). |
| R-08 | 2026-11-03 | D-14 apps, load shaper, footprint log, astroshop Secret refresh; ENH-152 `delivery`. bats now has 19 tests. Mutations: the refresh always restarts; apply ignores its state; no floor on the targets; a port clash; an unknown cluster; a missing heal branch; `isProblemGeneratorRunning` always true; stop that does not kill. `sync check-delivery` at fw `d57abd3`, with and without the block. `tg lint`. `mkdocs build --strict` | 19/19 pass, and every mutation failed a test. **Found and fixed a test bug:** a bats line like `! cmd` never fails a test (`set -e` ignores it), so 4 assertions (3 here, 1 in the test repo) had never been able to fail; they now use `run` and check the status. delivery rc 0, and rc 1 without the block. lint 0 errors / 12 warnings. mkdocs green. |
| R-09 | 2026-11-04 | Framework 1.18.0 → 1.20.3 and image `dt-enablement` v1.3.2 → v1.4.0 (D-16). `bats .devcontainer/test/shared-box.bats`. `tg lint` (generator venv). Docs built as CI does: the pinned framework's `mkdocs-base.yaml`, `extra.css` and `mermaid.min.js` at 1.20.3, `mkdocs build`, and once more with `--strict`; the same for `main` at 1.18.0 | bats 19/19. lint 0 errors / 12 warnings (unchanged). `mkdocs build`: 0 warnings at 1.20.3. `--strict`: only `training_name` (the same on `main`, see R-04). |
| R-11 | 2026-11-05 | Slimmer load (D-14 fix). bats: 28 tests. Mutations: guard comparison flipped; loop bypasses the guard; a missing cap; a cap error swallowed; reading `oom` instead of `oom_kill`; the easytrade peak back to 3. Before (staging, 209, `ec870f3`): slot `memory.peak` 58,563 / 59,284 MiB, `oom_kill` 158, `pids.peak` 9,246 | 28/28 pass, and each mutation failed at least one test. **After, PASS on the changed criterion (see the next sentence):** staging booking `ws_mw3f0a54-a3c8ff` on SRO, branch-pinned, box `i-0161553ae7cbfeb93` (m6a.4xlarge). Pool READY 4 min after booking; build 15.6 min; data from all 3 clusters in SRO (metrics, logs, spans, events, a problem). Sampled every minute for 16 min at curve hour 11 (100 % load): **`oom_kill` 0, dmesg 0 kills, anon + kernel ≤ 20.2 GiB, `memory.pressure` full avg60 0.00**, `pids.peak` 8,744. **Raw `memory.peak` was 58.6 GiB — the same as before, NOT under 45.** It counts page cache: anon 17 GiB, kernel 2.7 GiB, file 38 GiB (36.8 GiB inactive, the k3d nodes' image cache). So the target was changed (orch, 2026-11-05) from "memory.peak ≤ 45 GiB" to "0 OOM kills, anon + kernel ≤ 45 GiB, no memory pressure". `memory.events max` reached 2,509: the slot touched its ceiling and the kernel reclaimed cache, with no stall. Ended 11:19Z; EC2 terminated 11:23:15Z; staging fleet back to 3. |
| R-13 | 2026-11-06 | ENH-163 F13 (BUG-199): the owner's COE run showed "kubernetesClusterMEID is outdated". Staging booking `ws_mw50ddgq-d7df2a` on SRO, BYOA `a7e0544`, framework 1.20.3, operator 1.10.2. Per cluster: kube-system UID, MEID, DynaKube conditions, operator log, dtctl. Then on sec: a live token, a revoked token, the live token restored; and the trainer's Refresh tokens. bats: `byoaDynakubeHealth` + the `trainingHealth` hook, 7 tests (43 in total). Mutations: judge on any 401 in the window; drop the 401 branch | **Not a shared MEID:** shop/ops/sec have distinct kube-system UIDs and MEIDs (`…1CDA372E34308E7E`, `…0010357AF6455179`, `…7504D420C7B0602A`); metrics, logs and spans from all 3 in SRO. **The symptom is a dead operator token:** revoked (DELETE 204) → MonitoredEntity False/StatusOutdated "kubernetesClusterMEID is outdated in the status", phase Error, operator `HTTP 401: Token Authentication failed`; the live token restored → "up to date". A `dt0s16` operator token also works. Refresh `rf-7ab8f9da5c8e` applied rc 0: all 3 Secrets and `.env` on the same new tokens. bats 43/43; each mutation failed its test (39, 38). Ended 14:2xZ (ended via live-end); EC2 terminated 14:24:11Z. |
| R-14 | 2026-11-08 | ENH-163 F13 fix 2 (BUG-199, D-17): framework 1.22.0 registers each cluster itself (`builtin:cloud.kubernetes` by kube-system UID), then waits until the DynaKube reports the object's MEID; fatal on the shared box (`ORBITAL_SHARED_ROLE=shared`). Staging bookings on BOTH test tenants, branch `chore/framework-1.22.0`, Orbital `fc5b9a0` (PVF spot `e41f8b4`), app `afcaa87`: SRO `ws_mw7uw3of-cb7782` (classic `dt0c01` tokens) and PVF `ws_mw7wtlkc-0a3157` (platform `dt0s16` tokens). Negative control on sec in a subshell (operator token = the ingest token, temp kubeconfig and state file). Removal through `dynatraceRemoveK8sRegistrations` (UID + label guard), read back with dtctl | **PASS.** The build log shows `Registering Kubernetes cluster …`, then `registered as KUBERNETES_CLUSTER-…; the DynaKube resolved it`, for each cluster: SRO shop/ops/sec `…6B4D3BAB79E3B895` / `…9136BF0A081E3570` / `…C05982738ACFFCB5`, PVF `…FE201F21CB077D4B` / `…DD808CF2872F8042` / `…E98D4487622A09CF`. The DynaKube `status.kubernetesClusterMEID` equals the object's scope, MonitoredEntity True, `byoaDynakubeHealth` ok ×3, and Grail has metrics from all 3 clusters on both tenants. **Negative control:** SRO: the read fails with GET 403 `Token is missing required scope. Use one of: settings.read`; validateOnly gives 403 `… settings.write`. PVF: the GET is **200** (adopt, rc 0, correct); validateOnly gives **404** `No write access for scope class tenant`. With an unregistered UID: rc 1, nothing created. **Defect found:** on SRO, 1.22.0 returned rc 1 with NO message, because the finder's error went to stdout inside `$(…)`. Framework PR #224 fixes it (stderr, plus 401/403 wording on the read, and 404 = no settings.write); verified live; bats 27/27; mutations red. **Removal:** 3/3 removed per tenant (rc 0, state file emptied); dtctl `not found` ×3; 0 of 476 (SRO) and 0 of 88 (PVF) objects carry the hostgroup. Removal ran from the box BEFORE End: Orbital's pre-stop still calls `undeployMonaco`, not `frameworkTeardown` (ENH-168), so End alone would have left them. Ended SRO 14:07:37Z, EC2 `i-0e813ec08c42fda16` terminated 14:10:19Z. Ended PVF 14:38:42Z, EC2 `i-0526946ce22edd8a3` terminated 14:41:17Z. |
