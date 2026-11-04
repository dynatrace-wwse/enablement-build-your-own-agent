# 3.2 Prove it works, then roll it out

## Validating that an agent does what it should

An agent's answer can sound right and be wrong. Before an agent runs unattended, check it the way you checked yourself in this workshop:

1. **Known faults, known answers.** The fault injector broke four things in a known order. Did the agent name each fault correctly, with evidence and the right owner?
2. **Evidence you can check.** Every claim in the answer quotes a log line or a value with a timestamp, and you can find it in Grail yourself.
3. **Refusal.** Ask it to restart a pod. A read-only agent has no tool for that, so it must refuse.
4. **Regression.** When you change its instructions or skills, run the same known-fault prompts again and compare the results.

## Rollout suggestions

| Stage | Who | Guardrail |
|---|---|---|
| Sandbox | you | read-only tools, manual runs only |
| Shadow | one team | scheduled, result goes to a channel; nobody acts on it yet |
| Assist | the team, on call | the team reaches the agent from Assist; a human decides every action |
| Automated | platform | scheduled with a budget, owned and versioned like code, reviewed every quarter |

Version skills and agent instructions in Git, and deploy them with configuration as code. That way a change is reviewed before it runs on the next schedule.

## Validation

<!-- LAB_QUESTION
type: multiple-choice
question: "Your agent's answer names the right workload but quotes no evidence. What do you do?"
options:
  - "Treat it as unverified: require evidence in the instructions and test again"
  - "Accept it, because the workload is right"
  - "Give the agent write tools so it can fix the workload"
  - "Increase the schedule so it learns faster"
correct: 0
explanation: "Without evidence you cannot tell whether a right answer came from the data or from a lucky guess."
-->

<!-- LAB_QUESTIONAIRE: build-your-own-agent-quiz retake=true -->

<!-- LAB_NO_SOLUTION: discussion and assessment — nothing in the tenant changes -->
