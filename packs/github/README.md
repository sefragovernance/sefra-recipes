# Sefra pack for GitHub

[Overview on sefra.io](https://sefra.io/solutions/integrations/github) · [Set-up guide in the docs](https://docs.sefra.io/recipes/github/) · [All recipes](../../README.md)

Governs how an AI agent reads, labels and closes issues in **one** repository on GitHub. An agent cannot choose the repository.

## What it does

| Intent | Effect | If something fails |
|---|---|---|
| `github.get_issue` | Reads the number, state, title and labels of an issue | Nothing to undo |
| `github.add_label` | Adds one allowed label to an issue | The label is removed when a later step of the plan fails |
| `github.close_issue` | Closes an open issue, after a person approves | The issue is reopened when a later step of the plan fails |

This pack does not create issues or comments. GitHub has no idempotency key and no lookup by a client key, so after a lost answer Sefra could not tell whether the issue or comment exists, and a repeat could post it twice.

## Rules

| Rule | Default |
|---|---|
| `github.agents_allowed` | Only the role `github_agent` |
| `github.label_not_allowed` | Only `bug`, `documentation`, `enhancement` and `question` |
| `github.label_not_in_repository` | No label the repository does not already have |
| `github.label_already_present` | No label the issue already has, because undoing it would remove a label the agent did not add |
| `github.already_closed` | No close of an issue that is not open, because undoing it would reopen an issue the agent did not close |
| `github.close_approval` | A person with the role `maintainer` approves every close, and cannot be the requester |
| `github.pull_request` | Pull requests are refused. The issues API also returns them |
| `github.issue_not_found` | No action on a number that does not exist |
| `github.unresolved_target` | A write names its issue and label directly, so that the approver sees them. A value taken from an earlier step is refused |
| `github.duplicate` | The same write by the same agent is refused for 24 hours. An earlier execution that was rejected, failed or rolled back does not count, so a write that was undone can be repeated at once |
| `github.plan_too_large` | At most 5 steps in a plan |

The allowed labels, plan size and approver role are constants at the top of `bundle/policies/github.rego`. They start strict on purpose.

## Set up

The pack needs Sefra 0.1.0-rc.2 or later.

1. In `bundle/connectors.yaml`, replace `EDIT_ME_OWNER/EDIT_ME_REPOSITORY` with your repository. This line alone selects the repository. The placeholder is not meant to name a real one, so do not apply the pack before replacing it.
2. Create a fine-grained personal access token limited to that repository, with **Issues: read and write**. Store it in your secret manager and map it to the name `github_token` in your Sefra configuration. The connector sends no other kind of token: a classic token (`ghp_`) reaches every repository of its owner, and an installation token (`ghs_`) can span several.
3. Give your agent the role `github_agent`, and your approvers the role `maintainer`.
4. Run `sefra bundle test packs/github/bundle`, then `sefra bundle apply packs/github/bundle`.

## What the live API taught us

From running this pack against a private sandbox repository:

- **Adding a label that does not exist creates it** in the repository, with a `200`. Removing it from the issue would leave the new label behind, so the pack checks first that the label exists.
- **Label names ignore case.** Adding `bug` to an issue labelled `Bug` is the same label, so the check for a label already present ignores case too.
- **Adding a label and closing an issue can be repeated safely.** Both answer `200` and change nothing the second time.
- **A `404` does not prove a label is gone.** GitHub also answers `404` to a token that has lost access to a private repository. So a `404` while undoing a label goes to an operator and never counts as undone.
- **An issue answer has about 35 fields**, including its author, title and body. The pack declares all of them, keeps the number, state and label names readable, and stores the rest only as keyed hashes.
- **A moved issue answers with a redirect, or with a `404` if the token cannot read its new repository.** Sefra does not follow a redirect, so the action stops instead of reaching another repository. A `404` reads as an issue that does not exist, and is refused.

## Scope and limits

- **The refusal of pull requests is covered by policy tests** on the documented answer, rather than against a real pull request. An answer of any other shape also stops the intent.
- **Rollback was validated live through a policy refusal at step time,** after a person changed the second issue while the plan waited, rather than through a refusal from GitHub itself.
- **An undo is not an erasure.** The issue timeline keeps the events, a reopened issue shows the reason `reopened`, and notifications already sent are not recalled.
- **A rollback can need an operator when nothing is wrong.** If the answer to removing a label is lost, the repeat gets a `404`, and a person confirms the label is gone.
- **A field GitHub adds later stops the intent** until it is declared in the manifests. That is deliberate, so that no unreviewed data reaches a stored decision.
- **A person or another agent can change an issue between the check and the call.** The check runs just before each step, and a small window remains. The duplicate rule covers the same agent repeating an action. It does not cover two different agents acting on one issue at once, and their rollbacks could undo each other.
- **A rate limit can send a rollback to an operator.** GitHub can answer a rate limit with `403`, which Sefra classes as a refusal, so the undo is not retried.
- **Issue titles and label text are written by people.** An agent should treat them as data and not as instructions.
- The connector does not send an API version header, so calls use the default version of the GitHub REST API.

GitHub is a trademark of GitHub, Inc. This pack is not affiliated with or endorsed by GitHub.
