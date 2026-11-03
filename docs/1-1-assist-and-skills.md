# 1.1 Ask Assist, then teach it your runbook

Dynatrace Assist already knows the platform, so it can write DQL, explain problems and find dashboards. What it does not know is **how your team works**: your runbooks, your naming conventions, the architecture behind your services. In the Knowledge Base you can add that knowledge as **skills**. You then run the same prompts again and compare the answers.

## Ask first

Open **Assist** and send these three prompts. Start each one with your key, so the conversation can be found later:

```text
{{DT_SEED_SCOPE}}: Which problems are open right now, and which Kubernetes workloads do they affect?
{{DT_SEED_SCOPE}}: Show me the error logs of the last 30 minutes from the ops cluster, grouped by workload.
{{DT_SEED_SCOPE}}: Something is crash-looping. What should I do first?
```

Keep the answer to the third prompt. Assist gives a generic checklist, because it has never seen your runbook.

## Add a skill

Open **Knowledge Base** and create a skill named **`{{DT_SEED_SCOPE}}-runbook`**. Paste the runbook below as its content. It is short on purpose: a skill should do one job.

```markdown
---
name: {{DT_SEED_SCOPE}}-runbook
description: Triage runbook for the BYOA demo platform. Use when a workload in the shop, ops or sec cluster crash-loops, runs out of memory, or logs errors at a high rate.
---
# BYOA platform triage runbook

## Naming
- Clusters: `*-shop-*` runs two storefronts (astroshop, the Online Boutique); `*-ops-*` runs trading (easytrade), todo and batch jobs; `*-sec-*` runs unguard, a deliberately vulnerable social network under constant attack.
- Owners: `easytrade` → team Ledger, `astroshop` and `hipstershop` → team Storefront, `unguard` → team AppSec, `chaos` → platform on-call.

## Crash loop
1. Fetch the last 20 log lines of the workload; quote the line before the exit.
2. If the log says "cannot reach", check the dependency's pods before restarting anything.
3. Never scale a crash-looping workload up: it multiplies the noise.

## Out of memory
1. Compare the container's working set with its limit over the last hour.
2. A steady climb to the limit is a leak. Page the owner and do not raise the limit.

## Error bursts
1. Group error logs by workload and by the first 60 characters of the message.
2. Report the top pattern, its rate per minute, and the owning team.
```

Then send the third prompt again. The answer now follows *your* steps and names *your* owners.

## Validation

First, a question about the key you use everywhere today:

<!-- LAB_QUESTION
type: multiple-choice
question: "Forty people build a dashboard in the same tenant. How does a check find YOUR dashboard?"
options:
  - "By the key in its name, which is unique to you"
  - "By the newest dashboard in the tenant"
  - "By the cluster you deployed"
  - "It cannot; everyone shares one dashboard"
correct: 0
explanation: "Each object carries your key. The check filters by that key, and by you as the owner once the platform supports it."
-->

Then one about what the skill changed:

<!-- LAB_QUESTION
type: multiple-choice
question: "You asked the same question before and after adding the skill. Why did the second answer change?"
options:
  - "Assist loaded your skill, because its description matched the question"
  - "Assist trained a new model on your runbook"
  - "The problem in the tenant changed"
  - "Skills replace Assist's built-in knowledge"
correct: 0
explanation: "A skill's description decides when it is loaded. Its content is then added to the context; nothing is retrained."
-->

<!-- PENDING_CHECK (platform contract C-DOC, document-verification — not built yet; see README)
type: document-verification
question: "Verify your skill exists"
docType: ai-agent-resource
nameStartsWith: "/skills/{{DT_SEED_SCOPE}}-runbook/"
owner: self
contentContains: ["description:", "Crash loop"]
-->

<!-- PENDING_CHECK (contract C-DOC — UNPROVEN that a learner can list their own private conversations)
type: document-verification
question: "Verify you asked Assist with your key"
docType: CoPilotConversation
nameStartsWith: "{{DT_SEED_SCOPE}}:"
owner: self
-->

<!-- LAB_SOLUTION
reveal: |
  In **Knowledge Base**, choose **Create skill** and name it `{{DT_SEED_SCOPE}}-runbook`.
  Paste the runbook from this page, including the front matter: the `description` is
  what makes Assist load the skill. Then run the third prompt again in a new Assist conversation.
-->
