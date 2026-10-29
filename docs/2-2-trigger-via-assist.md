# 2.2 Call your agent from Assist

An agent becomes useful when people reach it where they already work. In **Assist**, address your agent by name:

```text
{{DT_SEED_SCOPE}}: @{{DT_SEED_SCOPE}}-triage-agent triage the open problems on the ops cluster
```

Compare the answer with the generic one from step 1.1. It should be a table, it should quote evidence, and it should name an owner from your runbook.

Now change one line of the agent's instructions, for example ask for a severity column, and call it again. A change to the instructions takes effect on the next call. You do not need to deploy anything.

## Validation

<!-- LAB_QUESTION
type: multiple-choice
question: "The agent's answer names 'team Ledger' as the owner. Where did that come from?"
options:
  - "From the runbook skill attached to the agent"
  - "From the Kubernetes labels of the workload"
  - "Assist guessed it"
  - "From the problem's root-cause analysis"
correct: 0
explanation: "Ownership exists only in your runbook. Because the answer names it, you know the skill was used."
-->

<!-- PENDING_CHECK (contract C-DOC, CoPilotConversation — UNPROVEN, see README)
type: document-verification
question: "Verify you called your agent from Assist"
docType: CoPilotConversation
nameStartsWith: "{{DT_SEED_SCOPE}}: @{{DT_SEED_SCOPE}}-triage-agent"
owner: self
-->

<!-- LAB_SOLUTION
reveal: |
  In Assist, type `@` and pick `{{DT_SEED_SCOPE}}-triage-agent`, then ask it to triage the open
  problems. If the agent is not offered, check that it is saved in Agent Studio under exactly
  that name.
-->
