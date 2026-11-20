# 2.3 Run your agent on a schedule from a workflow

So far a person had to ask. In this step a **workflow** runs the agent on a schedule, and whoever is on call reads the result instead of starting from an empty screen.

## Build the workflow

In **Workflows**, create a workflow named **`{{DT_SEED_SCOPE}} · BYOA triage`**:

1. **Trigger:** a schedule that runs every 30 minutes. Never schedule it more often: in Part 3 you will see why.
2. **Task `triage`:** the agentic AI action **Run agent**, with
    - **AI Agent:** `{{DT_SEED_SCOPE}}-triage-agent`
    - **Prompt:** `Triage the open problems. Only problems opened in the last 30 minutes.`
3. **Task `notify`** (optional): send the `triage` result to the workshop channel your trainer shows.

Select **Save**. Do not run it yet.

## Check: your workflow is deployed

Saving deploys the workflow to the tenant, and Dynatrace records who created it. This check finds a workflow that **you** created (or that your trainer deployed for you, see the solution), whose title starts with your key, and that has not been deleted since:

<!-- LAB_QUESTION
type: dql-verification
question: "Verify your workflow is deployed"
buttonText: "Check workflow deployed"
dql: |
  fetch dt.system.events, from:now()-7d
  | filter event.kind == "WORKFLOW_EVENT"
  | filter in(event.type, {"WORKFLOW_CREATED", "WORKFLOW_UPDATED", "WORKFLOW_DELETED"})
  | sort timestamp asc
  | summarize creator = takeFirst(if(event.type == "WORKFLOW_CREATED", user.id)),
              title = takeLast(dt.automation_engine.workflow.title),
              deleted = countIf(event.type == "WORKFLOW_DELETED"),
              by:{dt.automation_engine.workflow.id}
  | filter deleted == 0
  | filter startsWith(title, "{{DT_SEED_SCOPE}} · ")
  | filter in(creator, {"{{DT_USER_ID}}", "{{DT_SOLUTION_ACTOR}}"})
  | summarize workflows = count()
expect:
  operator: gte
  field: workflows
  value: 1
pollSeconds: 10
timeoutSeconds: 120
hint: "Save the workflow first. Its title must start with your key, then a space, a middle dot (·) and a space: copy it from this page. A workflow someone else created does not count, even with your key in its title."
explanation: "A workflow you created, with your key at the start of its title, is deployed in the tenant and has not been deleted."
-->

## Run it

Select **Run** once, so you do not have to wait for the schedule.

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

<!-- LAB_SOLUTION
reveal: |
  Create the workflow with a schedule trigger (every 30 minutes) and one task that uses
  **Dynatrace Intelligence → Run agent** with your agent `{{DT_SEED_SCOPE}}-triage-agent` and the
  prompt from this page. Name it exactly `{{DT_SEED_SCOPE}} · BYOA triage`. Save it, then select **Run**.

  The same workflow also exists as configuration as code: `monaco/tenant/byoa-workflow/` in the
  training repository. Your trainer can deploy it for you from the shared box with
  `byoaSolveWorkflow {{DT_USER_EMAIL}}` (Monaco, `deployMonaco tenant --for {{DT_SEED_SCOPE}}`).
  The copy is created by the workshop's own service user, so it counts for your "deployed" check.
  Its first run still needs the agent `{{DT_SEED_SCOPE}}-triage-agent` from step 2.1.
-->
