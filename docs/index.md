---
description: "Use Dynatrace Assist, skills and your own agents in the tenant. Then run those agents on a schedule from a workflow and roll them out safely."
tags: [ai, agents, assist, workflows, perform]
difficulty: intermediate
duration: 175 # minutes: intro 10 · part 1 60 · break 5 · part 2 70 · part 3 30
delivery:
  availability: workshop-only   # it has a shared box (workshop-post-create.sh): ENH-152
  tenancy: single               # trainer and learners on the trainer's tenant
---

# Build Your Own Observability Agent with Dynatrace

## What you will be able to do

By the end you have built a custom observability agent in Dynatrace and grounded it in your own runbook. You have also had it triage live problems on a schedule from a workflow, with a guardrail that keeps its cost bounded.

## Who it is for

This session is for platform engineers, SREs and observability leads who already use Dynatrace and want AI to do the repetitive investigation work. You need basic DQL. You do not need to code.

## How this workshop works

Everyone in the room works in **one shared Dynatrace tenant**. Your trainer's machine has been running since the day before and keeps generating real telemetry for the tenant to analyse:

- three Kubernetes clusters
- two web shops, a trading app, a to-do service and a deliberately vulnerable social network, written in Java, Go, .NET, Node.js, Python and PHP
- traffic that follows a working day: quiet at night, busy at noon
- a fault injector that breaks something new every twenty minutes: CPU, memory, errors, latency, traffic, outages

You do everything in the Dynatrace UI. There is no terminal for you to use.

Because forty people build the same things in one tenant, **every object you create carries your key**:

<div class="byoa-key" markdown>
**Your key: `{{DT_SEED_SCOPE}}`**
</div>

| You create | Name it exactly |
|---|---|
| Notebook | `{{DT_SEED_SCOPE}} · BYOA notebook` |
| Dashboard | `{{DT_SEED_SCOPE}} · BYOA dashboard` |
| Knowledge Base skill | `{{DT_SEED_SCOPE}}-runbook` |
| Custom agent | `{{DT_SEED_SCOPE}}-triage-agent` |
| Workflow | `{{DT_SEED_SCOPE}} · BYOA triage` |

Every check in this training looks for *your* object by your key. If the name is wrong, the check cannot find the object, even when the object itself is right.

!!! tip "A query proves itself with an alias"
    Some checks look for a DQL query you ran. Those checks ask you to name one result column with your key, like this:
    `` | summarize `byoa_{{DT_SEED_SCOPE}}` = count() ``.
    Dynatrace records every query that runs, but it masks comments and quoted text in that record. A column name is the one part of the query that is recorded as you wrote it.

## Agenda

| Part | Time | What you do |
|---|---|---|
| Intro | 10 min | Your key, the shared tenant, what is running |
| 1. Explore with Assist | 60 min | Ask Assist, add a skill from your runbook, generate a notebook and a dashboard. Preview: dtctl and the remote MCP server |
| Break | 5 min | |
| 2. Build your own agent | 70 min | Build an agent in Agent Studio, call it from Assist, then run it from a workflow on a schedule |
| 3. Scale safely | 30 min | Guardrails and cost, how to check that an agent does its job, and how to roll it out |

<!-- LAB_NO_SOLUTION: welcome page — nothing in the tenant changes -->

<!-- checklist [ ] gen-structure: Layout: welcome, three parts, resources, assessment on the last step -->
<!-- checklist [ ] gen-mkdocs-strict: mkdocs build in strict mode passes -->
<!-- checklist [x] gen-dql-parsed: Every DQL check parsed on the sprint tenant (2026-10-29) -->
<!-- checklist [ ] gen-dql-verified: Every DQL check passed on SRO with a real learner run -->
<!-- checklist [ ] human-checks-fail-first: Every check fails before its step's action and passes after it -->
<!-- checklist [ ] human-duration: The duration matches a timed dry run (175 min) -->
<!-- checklist [ ] human-no-internal: No internal content (Juno answers, internal links) in the repo -->
