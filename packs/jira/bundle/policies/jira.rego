# Rules of this pack for Jira. Edit the constants to fit your project and
# workflow; they start strict on purpose.
#
# Allow on what is known at submission (principal, intent type). Data-dependent
# constraints are deny rules, which do not fire while a value they read is still
# unresolved at pre-flight, and run again just before each step.
package policies.jira

# The only project an agent may act in. Replace it here and in the issue_key
# pattern of each manifest.
project_key := "EDIT_ME_PROJECT"

# The only labels an agent may add. Jira labels are case-sensitive.
allowed_labels := {"agent-reviewed", "needs-info", "triaged"}

max_plan_steps := 5

approver_role := "project_lead"

# The one status move this pack makes, and the transition ids of your workflow.
# The ids are also in intents/jira.start_work.yaml.
from_status := "To Do"

to_status := "In Progress"

start_transition := "21"

undo_transition := "11"

write_intents := {"jira.add_label", "jira.start_work"}

intents := write_intents | {"jira.get_issue"}

# jira.agents_allowed
allow if {
	"jira_agent" in input.principal.roles
	input.intent.type in intents
}

# jira.issue_not_found
deny contains {
	"rule": "jira.issue_not_found",
	"message": "Jira has no issue with this key, or this account cannot see it.",
	"path": "/issue_key",
	"hint": "Check the issue key.",
} if {
	input.intent.type in intents
	input.facts.issue == null
}

# jira.wrong_project: an issue moved to another project keeps answering to its
# old key, with its new key and project in the answer.
deny contains {
	"rule": "jira.wrong_project",
	"message": "This issue is not in the project this pack governs.",
	"path": "/issue_key",
	"limit": project_key,
	"hint": "Use an issue of the configured project, by its current key.",
} if {
	input.intent.type in intents
	wrong_project
}

wrong_project if input.facts.issue.fields.project.key != project_key

wrong_project if input.facts.issue.key != input.input.issue_key

wrong_project if {
	key := input.input.issue_key
	not startswith(key, sprintf("%s-", [project_key]))
}

# jira.label_not_allowed
deny contains {
	"rule": "jira.label_not_allowed",
	"message": "This label is not on the list an agent may add.",
	"path": "/label",
	"actual": label,
	"limit": sort(allowed_labels),
	"hint": "Use one of the labels in limit.",
} if {
	input.intent.type == "jira.add_label"
	label := input.input.label
	not label in allowed_labels
}

# jira.label_already_present: undoing this step would remove a label it did not
# add. Jira keeps labels that differ in case apart, so this compares exactly.
deny contains {
	"rule": "jira.label_already_present",
	"message": "The issue already has this label.",
	"path": "/label",
	"hint": "Nothing to do.",
} if {
	input.intent.type == "jira.add_label"
	input.input.label in input.facts.issue.fields.labels
}

# jira.not_in_expected_status: undoing this step moves the issue to from_status,
# so it may start only from there. Any other status is refused.
deny contains {
	"rule": "jira.not_in_expected_status",
	"message": "The issue is not in the status this action starts from.",
	"path": "/issue_key",
	"actual": input.facts.issue.fields.status.name,
	"limit": from_status,
	"hint": "Only an issue in the status in limit can be started.",
} if {
	input.intent.type == "jira.start_work"
	input.facts.issue.fields.status.name != from_status
}

# jira.workflow_mismatch: a transition id means something else in another
# workflow, so both ids must lead to the expected statuses.
deny contains {
	"rule": "jira.workflow_mismatch",
	"message": "The workflow does not offer the transitions this pack is configured for.",
	"path": "/issue_key",
	"hint": "Ask an administrator to set the transition ids of this pack for your workflow.",
} if {
	input.intent.type == "jira.start_work"
	"transitions" in object.keys(input.facts)
	not workflow_matches
}

workflow_matches if {
	offers(start_transition, to_status)
	offers(undo_transition, from_status)
}

offers(id, status) if {
	some t in input.facts.transitions.transitions
	t.id == id
	t.to.name == status
	t.isAvailable == true
}

# jira.unresolved_target: with a value that a plan resolves later, the
# approver's summary would not name the issue or the label.
deny contains {
	"rule": "jira.unresolved_target",
	"message": "The issue and label of a write must be given directly, not taken from an earlier step.",
	"actual": input.unresolved.input,
	"hint": "Read the issue first, then submit the write with its key.",
} if {
	input.intent.type in write_intents
	count(input.unresolved.input) > 0
}

# jira.duplicate: two executions of one action could undo each other.
deny contains {
	"rule": "jira.duplicate",
	"message": "The same action was accepted in the last 24 hours.",
	"actual": input.facts.sefra.duplicates_24h,
	"limit": 0,
	"hint": "Check the earlier execution instead of repeating it.",
} if {
	input.intent.type in write_intents
	input.facts.sefra.duplicates_24h >= 1
}

# jira.plan_too_large
deny contains {
	"rule": "jira.plan_too_large",
	"message": "The plan has more steps than this bundle allows.",
	"actual": input.plan.size,
	"limit": max_plan_steps,
	"hint": "Split the work, or ask a project lead.",
} if {
	input.intent.type in intents
	input.plan.size > max_plan_steps
}

# jira.start_work_approval
require_approval contains {
	"rule": "jira.start_work_approval",
	"message": "A person approves moving an issue to In Progress.",
	"approver": {"role": approver_role},
	"distinct_from_requester": true,
} if {
	input.intent.type == "jira.start_work"
}
