# Rules of this pack for Jira. Edit the constants to fit your project; they
# start strict on purpose.
#
# Allow on what is known at submission (principal, intent type). Data-dependent
# constraints are deny rules, which do not fire while a value they read is still
# unresolved at pre-flight, and run again just before each step.
package policies.jira

# The only project an agent may act in. Replace every occurrence of the
# placeholder, here and in the key patterns of each manifest.
project_key := "EDIT_ME_PROJECT"

# Labels an agent may add on its own.
routine_labels := {"agent-reviewed", "needs-info", "triaged"}

# Labels an agent may add only after a person approves.
approval_labels := {"escalated"}

allowed_labels := routine_labels | approval_labels

max_plan_steps := 5

approver_role := "project_lead"

write_intents := {"jira.add_label"}

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
# add. Jira keeps labels that differ in case apart, but a person reads them as
# one, so a variant in another case counts as present. It says nothing about an
# issue outside the project.
deny contains {
	"rule": "jira.label_already_present",
	"message": "The issue already has this label, possibly in another case.",
	"path": "/label",
	"hint": "Nothing to do.",
} if {
	input.intent.type == "jira.add_label"
	not wrong_project
	some existing in input.facts.issue.fields.labels
	lower(existing) == lower(input.input.label)
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

# jira.duplicate: two executions of one action could undo each other. Sefra does
# not count an earlier execution that was rejected, failed or rolled back.
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

# jira.label_approval
require_approval contains {
	"rule": "jira.label_approval",
	"message": "A person approves adding this label.",
	"approver": {"role": approver_role},
	"distinct_from_requester": true,
} if {
	input.intent.type == "jira.add_label"
	input.input.label in approval_labels
}
