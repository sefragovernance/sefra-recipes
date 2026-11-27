# Sefra pack for Jira

[Overview on sefra.io](https://sefra.io/solutions/integrations/jira) · [Set-up guide in the docs](https://docs.sefra.io/recipes/jira/) · [All recipes](../../README.md)

Governs how an AI agent reads and labels issues in **one** project on a Jira Cloud site. An agent cannot choose the site or the project.

**This pack requires a Jira account that can reach this project and no other.** See [Set up](#set-up) and [Scope and limits](#scope-and-limits).

## What it does

| Intent | Effect | If something fails |
|---|---|---|
| `jira.get_issue` | Reads the key, status, summary and labels of an issue | Nothing to undo |
| `jira.add_label` | Adds one allowed label to an issue. The label `escalated` waits for a person to approve it | The label is removed when a later step of the plan fails. A rollback runs no policy, so only a project-only account stops it from writing to an issue that has since moved to another project |

This pack does not create issues or comments. Jira has no idempotency key for them, so after a lost answer Sefra could not tell whether the issue or comment exists, and a repeat could post it twice.

It does not change an issue's status either. See the first finding under [What the live API taught us](#what-the-live-api-taught-us).

## Rules

| Rule | Default |
|---|---|
| `jira.agents_allowed` | Only the role `jira_agent` |
| `jira.wrong_project` | Only issues that Jira reports in the configured project, under the key the agent used. An issue moved away is refused |
| `jira.issue_not_found` | No action on a key Jira does not return |
| `jira.label_not_allowed` | Only `agent-reviewed`, `needs-info`, `triaged` and `escalated` |
| `jira.label_already_present` | No label the issue already has, in any case, because undoing it would remove a label the agent did not add |
| `jira.label_approval` | A person with the role `project_lead` approves the label `escalated`, and cannot be the requester |
| `jira.unresolved_target` | A write names its issue and label directly, so that the approver sees them. A value taken from an earlier step is refused |
| `jira.duplicate` | The same write by the same agent is refused for 24 hours. An earlier execution that was rejected, failed or rolled back does not count, so a write that was undone can be repeated at once |
| `jira.plan_too_large` | At most 5 steps in a plan |

The project, labels, labels needing approval, plan size and approver role are constants at the top of `bundle/policies/jira.rego`. They start strict on purpose.

## Set up

The pack needs Sefra 0.1.0-rc.2 or later.

1. **Create a dedicated Jira account that can reach this project and no other.** This is a requirement, not a recommendation. An API token acts with all the rights of its account across the site, and a Jira URL cannot limit it to one project. With a project-only account, an issue moved to another project answers `404`, and a rollback then stops and reaches an operator.
2. In `bundle/connectors.yaml`, replace `EDIT_ME_SITE` with your site and `EDIT_ME_ACCOUNT_EMAIL` with that account's email. A secret for any other account is never sent.
3. Replace **every** occurrence of `EDIT_ME_PROJECT` with your project key: in `bundle/policies/jira.rego`, in the `issue_key` pattern of both manifests, and in the output `key` pattern of `bundle/intents/jira.get_issue.yaml`. Then `grep -r EDIT_ME packs/jira/bundle` must find nothing. Do not apply the pack before that.
4. List your site's fields with `GET /rest/api/3/field`, and replace the `customfield_` entries in the `issue` fact of each manifest with the ids of your site. Mark each with `x-sefra-sensitive: true`.
5. Store `account-email:api-token` in your secret manager and map it to the name `jira_basic_auth` in your Sefra configuration.
6. Give your agent the role `jira_agent`, and your approvers the role `project_lead`.
7. Run `sefra bundle test packs/jira/bundle`, then `sefra bundle apply packs/jira/bundle`.

## What the live API taught us

From running this pack against a test project:

- **Status moves are left out because they cannot be undone safely.** In the test workflow every transition was available from every status, and repeating one answered `204`. So a repeat after a lost answer, or a move back during a rollback, would overwrite a status a person had set in the meantime. A Sefra manifest has no condition that could prevent this.
- **A write answers `204` with no body.** Only the status says it worked, so the live check confirms each effect by reading the issue and its history.
- **Adding or removing a label can be repeated safely.** Removing a label that is not there also answers `204`.
- **Labels are case-sensitive.** `triaged` and `Triaged` can sit on one issue as two labels. The pack treats them as the same label and refuses to add the second.
- **A request without valid credentials can answer `404`** instead of `401`. So a `404` while undoing a step goes to an operator and never counts as undone.
- **An issue answer carries about 50 fields**, including people, summary, description and comments. A Sefra manifest cannot send the `fields=` parameter, so the pack declares them all, keeps the key, project key, status name and labels readable, and stores the rest only as keyed hashes.

## Scope and limits

- **A rollback can write to an issue that has left the project, unless the account is project-only.** A compensation runs no policy and reuses the stored key for up to 24 hours, and a moved issue still answers to its old key. The project-only account in step 1 is what turns that call into a `404` for an operator. **The account used for this pack's live check is not project-only**, so this protection was not exercised live.
- **Moved issues are outside the scope of the live check,** which stays within one project. The refusal of forward calls is covered by policy tests on the documented answer, which carries the new key and project.
- **A label change can have side effects in Jira that an undo does not reverse.** Automation rules, webhooks, board filters and integrations can react to a label being added, and again to its removal. Check what your site runs on label changes before you enable this pack.
- **Rollback was validated live through a policy refusal at step time,** after a person changed the second issue while the plan waited, rather than through a refusal from Jira itself.
- **A custom field added to the site stops the intent** until it is declared in the manifests. That is deliberate, so that no unreviewed data reaches a stored decision. An issue whose answer is larger than 1 MiB stops it too.
- **An undo is not an erasure.** The issue history keeps the changes, and notifications already sent are not recalled. A Sefra manifest cannot send `notifyUsers=false`, so watchers are notified of each change.
- **A person or another agent can change an issue between the check and the call.** The check runs just before each step, and a small window remains. If a person adds the same label after the step ran, a rollback removes it. The duplicate rule covers the same agent repeating an action while the earlier one stands. It does not cover two different agents acting on one issue at once, and their rollbacks could undo each other.
- **A rollback can need an operator when nothing is wrong,** for example when an issue was deleted after the step ran.
- **The summary reaches the agent and stays in Sefra's execution record** until step outputs are purged, 30 days by default. The audit trail holds it only as a keyed hash.
- **Issue summaries and labels are written by people.** An agent should treat them as data and not as instructions. Labels stay readable in stored decisions, so do not put personal data in them.

Jira and Atlassian are trademarks of Atlassian. This pack is not affiliated with, endorsed by or sponsored by Atlassian.
