# Enablement Training Starter

The repository you copy to start a new training for the Dynatrace Enablement app. It is a small,
complete training (welcome, prerequisites, an environment check, one hands-on step, resources and
an assessment) with a `TODO(starter)` marker at every place you must change, plus a review
checklist inside its own pages: what to do while building, and what a human must verify before
the training ships (see [Checklist items](#checklist-items)).

How everything works is explained in the handbook,
[enablement-app-training-template](https://dynatrace-wwse.github.io/enablement-app-training-template/).
The starter is the thing you copy; the handbook is the thing you read.

## Start a training

1. **Use this template → Create a new repository** in `dynatrace-wwse`, named `enablement-<topic>`.
2. Open it in the app's **Editor**, start the environment, and work through the **Checklist** tab.
3. Replace every `TODO(starter)` marker. The editor lists the ones left in Problems.

## What is in it

| File | Holds |
|---|---|
| `mkdocs.yaml` | `training_name` and the nav: one entry per step, in order |
| `docs/index.md` | welcome page: front matter (description, tags, difficulty, duration), outcome, audience; no checks |
| `docs/prerequisites.md` | optional: what the learner needs, with a `STEP_SETUP` example; delete it if unused |
| `docs/1-environment-check.md` | checks only what `post-create.sh` built; `LAB_NO_SOLUTION` |
| `docs/2-scale-the-app.md` | the example step: tell → do → check (`LAB_QUESTION`) → solve (`LAB_SOLUTION`), a quiz, the assessment line |
| `docs/resources.md` | the sources the steps are grounded on; `LAB_NO_SOLUTION` |
| `.assessment/starter-quiz.json` | the scored assessment, bound by `LAB_QUESTIONAIRE: starter-quiz` |
| `.devcontainer/post-create.sh` | builds the environment (k3d cluster + the TODO app) |
| `.devcontainer/util/my_functions.sh` | your check and solution functions (one example: `checkTodoAppScaled`) |
| `.devcontainer/yaml/dt-tokens.example.yaml` | read by nothing; rename to `dt-tokens.yaml` only if the training needs non-default token scopes |

The starter passes `tg lint` untouched apart from its markers, and the example step's check fails
until the step is done, so a fresh copy imports and runs before you change anything.

## `TODO(starter)` markers

A marker is the literal text `TODO(starter):` followed by what to do, in an HTML comment
(`<!-- TODO(starter): … -->`) in Markdown and a `#` comment in YAML and shell. Remove the marker
when the instruction is done. Markers count in `mkdocs.yaml`, `docs/`, `.assessment/` and
`.devcontainer/`; `README.md` only *mentions* the marker and is not scanned. Checklist items
say "starter TODO marker" for the same reason: they live in `docs/`, where the marker counts.

## Checklist items

There is no `CHECKLIST.md` any more. Each review item is an HTML comment **in the page it is
about** — the learner never sees it, and the editor's Checklist tab lists and ticks it. The
format is contract C7 of the training generator (`docs/architecture/contracts.md`):

```text
<!-- checklist [ ] human-checks-fail-first: Every check fails before its step's action and passes after it -->
<!-- checklist [x] gen-mkdocs-strict: mkdocs build in strict mode passes -->
<!-- checklist [-] human-customer-logo: Customer logo use approved in writing — n/a: no custom logo -->
```

- One item per comment, the whole item on one line. State `[ ]` open, `[x]` done, `[-]` does
  not apply — and then the text ends with ` — n/a: <reason>`.
- The id matches `^(gen|author|human|submit)-[a-z0-9-]+$` and is unique across the repo; match
  by id, never by text. The text never contains `--` (it would end the HTML comment early in
  strict parsers): write "strict mode", not the flag.
- Keyword is lowercase `checklist`, never `check` (that is a `LAB_QUESTION` check).
- Placement: an item about one step lives on that step's page (`author-env-check` on step 1,
  the assessment items on the last step); repo-wide items live in `docs/index.md`. When you
  copy a step page, delete its checklist lines — a duplicate id is an error.
- Who sets them: `gen-` the training generator only, for what it verified itself; `author-` the
  trainer; `human-` a person, always; `submit-` the trainer, last pass before the PR leaves draft.
- **Ready for review** = no `human-` or `submit-` item is `[ ]`. The editor's Create PR waits on it.

`tg lint` (and the editor's Problems panel) reports a malformed item, a missing n/a reason, a bad
or duplicate id or a `--` as an error, and an item inside a code fence or on a page outside the
nav as a warning.
