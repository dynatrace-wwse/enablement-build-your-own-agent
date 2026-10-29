# 3.1 Guardrails and cost

An agent that runs on a schedule costs money every time it runs, and a loop makes no noise when it goes wrong. Before you trust an agent unattended, put limits on it:

- **What it can do.** Give it read-only tools and least-privilege permissions for whoever runs it. The workflow's actor is that runner.
- **How often it runs.** Use a schedule, not a trigger that fires on every event. A frequently scheduled agent can exhaust the tenant's AI request limit for *everyone*, including Assist.
- **How much it reads.** Keep the timeframe in the prompt short ("opened in the last 30 minutes"), and ask for small, structured output.
- **Who reads the result.** Send the result somewhere a person looks, and record that it ran.

## Measure your own agent

Run this in a notebook. It counts how often your workflow ran in the last hour and checks the result against a budget of 4 runs:

```dql
fetch dt.system.events, from:now()-1h
| filter event.kind == "WORKFLOW_EVENT" and event.type == "WORKFLOW_EXECUTION"
| filter contains(dt.automation_engine.workflow.title, "{{DT_SEED_SCOPE}}", caseSensitive:false)
| summarize runs = count()
| fieldsAdd within_budget = if(runs <= 4, "yes", else: "no")
```

## Validation

The check runs the same budget query for you. It passes when your agent ran at least once in the last hour, and no more than 4 times:

<!-- LAB_QUESTION
type: dql-verification
question: "Verify your agent stays within its run budget (at most 4 runs per hour)"
buttonText: "Check budget"
dql: |
  fetch dt.system.events, from:now()-1h
  | filter event.kind == "WORKFLOW_EVENT" and event.type == "WORKFLOW_EXECUTION"
  | filter contains(dt.automation_engine.workflow.title, "{{DT_SEED_SCOPE}}", caseSensitive:false)
  | summarize runs = count()
  | fieldsAdd within_budget = if(runs >= 1 and runs <= 4, "yes", else: "no")
expect:
  operator: eq
  field: within_budget
  value: "yes"
hint: "Either your workflow has not run in the last hour, or it ran more than 4 times. A schedule of 30 minutes plus one manual run stays within budget."
explanation: "Your agent ran at least once and stayed within budget."
-->

<!-- LAB_QUESTION
type: multiple-choice
question: "Your triage agent runs every minute on a busy tenant. What is the first thing to break?"
options:
  - "The tenant's AI request limit, which throttles Assist for everyone"
  - "Nothing, because agent runs are free"
  - "The Kubernetes cluster"
  - "Only your own workflow"
correct: 0
explanation: "Agentic actions share the tenant's AI request budget. A frequent schedule throttles everyone else."
-->

<!-- LAB_SOLUTION
reveal: |
  Set the workflow's schedule to 30 minutes (or slower). One manual run plus the schedule
  stays within 4 runs an hour.
-->
