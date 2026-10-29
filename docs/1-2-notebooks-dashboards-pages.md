# 1.2 Generate a notebook, a dashboard and a Page

Assist can produce more than answers. It can create the artifacts your team keeps: notebooks for investigations, dashboards for what everyone watches, and **Pages** for a result you want to keep and share.

## Notebook

Ask Assist:

```text
{{DT_SEED_SCOPE}}: Create a notebook that shows error logs per workload for the last hour, and the open problems.
```

Open the notebook it created and rename it **`{{DT_SEED_SCOPE}} · BYOA notebook`**. Then add one section of your own, with this query, and run it:

```dql
fetch logs, from:now()-1h
| filter loglevel == "ERROR"
| summarize `byoa_{{DT_SEED_SCOPE}}` = count(), by:{k8s.workload.name}
| sort `byoa_{{DT_SEED_SCOPE}}` desc
```

## Dashboard

Ask Assist for a dashboard with the same view, rename it **`{{DT_SEED_SCOPE}} · BYOA dashboard`**, and add a tile with the query above. Keep the column name exactly as written, because the check looks for it.

## Page

Ask Assist to summarise the open problems. From the answer, choose **Save as Page**, and give the Page the name **`{{DT_SEED_SCOPE}} · BYOA page`**.

## Validation

The first check proves that your dashboard ran your query. Dynatrace records every query and the app that ran it, and your `byoa_{{DT_SEED_SCOPE}}` column marks the query as yours:

<!-- LAB_QUESTION
type: dql-verification
question: "Verify your dashboard ran your query"
buttonText: "Check dashboard"
dql: |
  fetch dt.system.events, from:now()-3h
  | filter event.kind == "QUERY_EXECUTION_EVENT"
  | filter client.application_context == "dynatrace.dashboards"
  | filter contains(query_string, "byoa_{{DT_SEED_SCOPE}}")
  | summarize runs = count()
expect:
  operator: gte
  field: runs
  value: 1
hint: "Open your dashboard so its tiles run. Keep the column named `byoa_{{DT_SEED_SCOPE}}`, because the check looks for exactly that name. A run takes up to a minute to appear."
explanation: "Dynatrace recorded a query from the Dashboards app with your column name in it."
-->

The second check proves the same for your notebook. It accepts any app except Dashboards:

<!-- LAB_QUESTION
type: dql-verification
question: "Verify your notebook ran your query"
buttonText: "Check notebook"
dql: |
  fetch dt.system.events, from:now()-3h
  | filter event.kind == "QUERY_EXECUTION_EVENT"
  | filter isNotNull(client.application_context)
  | filter client.application_context != "dynatrace.dashboards" and client.application_context != "my.dynatrace.enablements"
  | filter contains(query_string, "byoa_{{DT_SEED_SCOPE}}")
  | summarize runs = count()
expect:
  operator: gte
  field: runs
  value: 1
hint: "Run the notebook section with the `byoa_{{DT_SEED_SCOPE}}` column. A run takes up to a minute to appear."
explanation: "Dynatrace recorded your query from an app other than Dashboards."
-->

<!-- PENDING_CHECK (contract C-DOC: document-verification; replaces the two query checks above once built)
type: document-verification
question: "Verify your notebook, dashboard and Page exist and are yours"
documents:
  - {docType: notebook,  nameEquals: "{{DT_SEED_SCOPE}} · BYOA notebook",  owner: self, contentContains: ["byoa_{{DT_SEED_SCOPE}}"]}
  - {docType: dashboard, nameEquals: "{{DT_SEED_SCOPE}} · BYOA dashboard", owner: self, contentContains: ["byoa_{{DT_SEED_SCOPE}}"]}
  - {docType: "<Pages type: OPEN>", nameEquals: "{{DT_SEED_SCOPE}} · BYOA page", owner: self}
-->

<!-- LAB_SOLUTION
reveal: |
  Create the notebook and the dashboard (asking Assist is fastest), rename both with your key,
  and add the query from this page as a section or tile. The column alias
  `byoa_{{DT_SEED_SCOPE}}` is what the check finds. Run the section, or open the dashboard,
  and wait a minute before you check.
-->
