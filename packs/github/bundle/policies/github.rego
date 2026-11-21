# Rules of this pack for GitHub. Edit the three constants to fit your repository;
# they start strict on purpose.
#
# Allow on what is known at submission (principal, intent type). Data-dependent
# constraints are deny rules, which do not fire while a value they read is still
# unresolved at pre-flight, and run again just before each step.
package policies.github

# The only labels an agent may add, in lower case.
allowed_labels := {"bug", "documentation", "enhancement", "question"}

max_plan_steps := 5

approver_role := "maintainer"

write_intents := {"github.add_label", "github.close_issue"}

intents := write_intents | {"github.get_issue"}

# github.agents_allowed
allow if {
	"github_agent" in input.principal.roles
	input.intent.type in intents
}

# github.issue_not_found
deny contains {
	"rule": "github.issue_not_found",
	"message": "The repository has no issue with this number.",
	"path": "/issue_number",
	"hint": "Check the issue number.",
} if {
	input.intent.type in intents
	input.facts.issue == null
}

# github.pull_request
deny contains {
	"rule": "github.pull_request",
	"message": "This number is a pull request, which this pack does not govern.",
	"path": "/issue_number",
	"hint": "Use the number of an issue.",
} if {
	input.intent.type in intents
	is_object(input.facts.issue) # null when the issue does not exist
	"pull_request" in object.keys(input.facts.issue)
}

# github.label_not_allowed
deny contains {
	"rule": "github.label_not_allowed",
	"message": "This label is not on the list an agent may add.",
	"path": "/label",
	"actual": label,
	"limit": sort(allowed_labels),
	"hint": "Use one of the labels in limit.",
} if {
	input.intent.type == "github.add_label"
	label := input.input.label
	not label in allowed_labels
}

# github.label_not_in_repository: GitHub would create it.
deny contains {
	"rule": "github.label_not_in_repository",
	"message": "The repository has no such label, and this pack does not create labels.",
	"path": "/label",
	"hint": "Ask a maintainer to create the label.",
} if {
	input.intent.type == "github.add_label"
	input.facts.repo_label == null
}

# github.label_already_present: undoing this step would remove a label it did
# not add. GitHub matches label names without regard to case.
deny contains {
	"rule": "github.label_already_present",
	"message": "The issue already has this label.",
	"path": "/label",
	"hint": "Nothing to do.",
} if {
	input.intent.type == "github.add_label"
	some l in input.facts.issue.labels
	lower(l.name) == lower(input.input.label)
}

# github.already_closed: undoing this step would reopen an issue it did not
# close. Any state other than open is refused.
deny contains {
	"rule": "github.already_closed",
	"message": "The issue is not open.",
	"path": "/issue_number",
	"actual": input.facts.issue.state,
	"hint": "Nothing to do.",
} if {
	input.intent.type == "github.close_issue"
	input.facts.issue.state != "open"
}

# github.unresolved_target: with a value that a plan resolves later, the
# approver's summary would not name the issue or the label.
deny contains {
	"rule": "github.unresolved_target",
	"message": "The issue and label of a write must be given directly, not taken from an earlier step.",
	"actual": input.unresolved.input,
	"hint": "Read the issue first, then submit the write with its number.",
} if {
	input.intent.type in write_intents
	count(input.unresolved.input) > 0
}

# github.duplicate: two executions of one action could undo each other.
deny contains {
	"rule": "github.duplicate",
	"message": "The same action was accepted in the last 24 hours.",
	"actual": input.facts.sefra.duplicates_24h,
	"limit": 0,
	"hint": "Check the earlier execution instead of repeating it.",
} if {
	input.intent.type in write_intents
	input.facts.sefra.duplicates_24h >= 1
}

# github.plan_too_large
deny contains {
	"rule": "github.plan_too_large",
	"message": "The plan has more steps than this bundle allows.",
	"actual": input.plan.size,
	"limit": max_plan_steps,
	"hint": "Split the work, or ask a maintainer.",
} if {
	input.intent.type in intents
	input.plan.size > max_plan_steps
}

# github.close_approval
require_approval contains {
	"rule": "github.close_approval",
	"message": "A person approves closing an issue.",
	"approver": {"role": approver_role},
	"distinct_from_requester": true,
} if {
	input.intent.type == "github.close_issue"
}
