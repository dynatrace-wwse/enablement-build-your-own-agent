# 2.3 Run your agent on a schedule from a workflow

So far a person had to ask. In this step a **workflow** runs the agent on a schedule, and whoever is on call reads the result instead of starting from an empty screen.

## Build the workflow

In **Workflows**, create a workflow named **`{{DT_SEED_SCOPE}} · BYOA triage`**:

1. **Trigger:** a schedule that runs every 30 minutes. Never schedule it more often: in Part 3 you will see why.
2. **Task `triage`:** the agentic AI action **Run agent**, with
    - **AI Agent:** `{{DT_SEED_SCOPE}}-triage-agent`
    - **Prompt:** `Triage the open problems. Only problems opened in the last 30 minutes.`
3. **Task `notify`** (optional): send the `triage` result to the workshop channel your trainer shows.

Save the workflow, then select **Run** once, so you do not have to wait for the schedule.

## Validation

Every workflow run is written to Grail as an event, together with each action it ran. This check finds a successful **Run agent** action in a workflow whose title carries your key:

<!-- LAB_QUESTION
type: dql-verification
question: "Verify your workflow ran the Run agent action successfully"
buttonText: "Check workflow run"
dql: |
  fetch dt.system.events, from:now()-3h
  | filter event.kind == "WORKFLOW_EVENT" and event.type == "ACTION_EXECUTION"
  | filter contains(dt.automation_engine.workflow.title, "{{DT_SEED_SCOPE}}", caseSensitive:false)
  | filter dt.automation_engine.action.function == "run-agent"
  | filter dt.automation_engine.state == "SUCCESS"
  | summarize runs = count()
expect:
  operator: gte
  field: runs
  value: 1
hint: "Select Run on your workflow and wait until the run finishes; an agent run takes about a minute. The workflow's title must contain your key."
explanation: "A workflow with your key in its title ran the Run agent action, and the action succeeded."
-->

This check proves that the schedule ran the workflow without anyone pressing Run. The trigger type of the run says how it started:

<!-- LAB_QUESTION
type: dql-verification
question: "Verify your workflow runs on a schedule"
buttonText: "Check schedule"
dql: |
  fetch dt.system.events, from:now()-3h
  | filter event.kind == "WORKFLOW_EVENT" and event.type == "WORKFLOW_EXECUTION"
  | filter contains(dt.automation_engine.workflow.title, "{{DT_SEED_SCOPE}}", caseSensitive:false)
  | filter dt.automation_engine.workflow_execution.trigger.type == "Schedule"
  | summarize runs = count()
expect:
  operator: gte
  field: runs
  value: 1
pollSeconds: 30
timeoutSeconds: 300
hint: "The first scheduled run comes at the next schedule time, up to 30 minutes after you saved. Move on and come back to this check."
explanation: "The workflow ran on its schedule, without anyone pressing Run."
-->

<!-- PENDING_CHECK (anti-copy, contract Q16 {{DT_USER_ID}}: join WORKFLOW_CREATED.user.id) -->

<!-- LAB_SOLUTION
reveal: |
  Create the workflow with a schedule trigger and one task that uses **Dynatrace Intelligence →
  Run agent** with your agent and the prompt from this page. The title must contain
  `{{DT_SEED_SCOPE}}`. Save the workflow, then select **Run**.
-->
