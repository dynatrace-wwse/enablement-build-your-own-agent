# 1.3 Preview: the same, from your own tools

Everything you did in Assist can also come from your laptop. **dtctl** is the Dynatrace CLI, and the **remote MCP server** exposes the same tools to any MCP client: Claude Code, Copilot, Cursor and others. Your coding agent can then query Grail, read problems and create documents under your permissions.

Your trainer shows this live, from the shared machine:

```text
dtctl query "fetch logs, from:now()-30m | filter loglevel == \"ERROR\" | summarize count(), by:{k8s.workload.name}"
dtctl get notebooks --mine
dtctl skills install --for claude    # teaches a coding agent how to drive dtctl
```

There is a full companion session on this topic. This workshop has no terminal for you, so this page is reference only.

<!-- LAB_QUESTION
type: multiple-choice
question: "Your coding agent uses the remote MCP server. Whose permissions does it act with?"
options:
  - "The permissions of the user or token it was connected with"
  - "Full admin, because MCP bypasses IAM"
  - "None: MCP is read-only by design"
  - "The permissions of the person who installed the MCP server"
correct: 0
explanation: "MCP tools call the same platform APIs, and those APIs enforce the same permissions."
-->

<!-- LAB_NO_SOLUTION: demo and reading page — learners have no terminal -->
