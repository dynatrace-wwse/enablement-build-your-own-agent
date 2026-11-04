# 2.1 Build your own agent in Agent Studio

A skill adds knowledge. An **agent** adds a job: its own instructions, a chosen set of tools and skills, and a defined output. You build one agent here, the triage agent, and use it in the rest of Part 2.

## Create it

In **Agent Studio**, create an agent named **`{{DT_SEED_SCOPE}}-triage-agent`** with:

- **Description:** `Triages open problems on the BYOA platform and names the owning team.`
- **Instructions:**

```text
You triage open Dynatrace problems on the BYOA demo platform.
For each open problem:
1. Name the affected Kubernetes workload and cluster.
2. Follow the {{DT_SEED_SCOPE}}-runbook skill for the matching failure type.
3. Quote one piece of evidence (a log line or a metric value) with its timestamp.
4. Name the owning team from the runbook.
Answer as a table: problem | workload | evidence | owner | next step.
Never suggest restarting or scaling anything. You only read.
```

- **Tools:** problems and Grail queries (logs, metrics). Leave out every tool that writes.
- **Skills:** `{{DT_SEED_SCOPE}}-runbook`.

!!! note "Least privilege starts here"
    An agent that only reads cannot make an incident worse. You return to this in Part 3.

## Validation

<!-- LAB_QUESTION
type: multiple-choice
question: "Which part of an agent decides WHAT it may do in the tenant?"
options:
  - "Its tools, together with the permissions of whoever runs it"
  - "Its description"
  - "Its name"
  - "The instructions alone"
correct: 0
explanation: "The instructions ask; the tools and the caller's permissions decide. Asking an agent not to write is weaker than giving it no tool that writes."
-->

<!-- PENDING_CHECK (contract C-AGENT — no supported listing API proven; owner question)
type: agent-verification
question: "Verify your agent exists with the runbook skill and read-only tools"
agentName: "{{DT_SEED_SCOPE}}-triage-agent"
owner: self
instructionsContain: ["{{DT_SEED_SCOPE}}-runbook", "Never suggest restarting"]
skillsInclude: ["{{DT_SEED_SCOPE}}-runbook"]
-->
<!-- Until C-AGENT exists the agent is validated through its USE in step 2.3 (a workflow run that called it). -->

<!-- LAB_SOLUTION
reveal: |
  In **Agent Studio**, choose **Create agent**. Use the name, description and instructions from
  this page, select only read tools, and attach the `{{DT_SEED_SCOPE}}-runbook` skill.
  Save the agent, then try it in the Agent Studio test panel with: "Triage the open problems."
-->
