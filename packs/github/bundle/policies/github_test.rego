# For each rule, a test that fires it and a test that does not.
package policies.github_test

import data.policies.github

open_issue := {"number": 7, "state": "open", "labels": [{"name": "question"}]}

label := {
	"phase": "step",
	"principal": {"id": "agent:github", "type": "agent", "roles": ["github_agent"]},
	"intent": {"type": "github.add_label", "version": 1, "effect": "write", "irreversible": false},
	"input": {"issue_number": 7, "label": "bug"},
	"facts": {"issue": open_issue, "repo_label": {"name": "bug"}, "sefra": {"duplicates_24h": 0, "denials_10m": 0}},
	"unresolved": {"input": [], "facts": []},
	"plan": {"size": 1, "index": 0, "intents": ["github.add_label"]},
	"env": {"time": "2026-11-21T10:15:00Z", "bundle_digest": "sha256:test"},
}

close := json.patch(label, [
	{"op": "replace", "path": "/intent/type", "value": "github.close_issue"},
	{"op": "replace", "path": "/input", "value": {"issue_number": 7, "reason": "completed"}},
	{"op": "remove", "path": "/facts/repo_label"},
	{"op": "replace", "path": "/plan/intents", "value": ["github.close_issue"]},
])

read := json.patch(close, [
	{"op": "replace", "path": "/intent", "value": {"type": "github.get_issue", "version": 1, "effect": "read", "irreversible": false}},
	{"op": "replace", "path": "/input", "value": {"issue_number": 7}},
	{"op": "replace", "path": "/plan/intents", "value": ["github.get_issue"]},
])

with_issue(x, issue) := json.patch(x, [{"op": "replace", "path": "/facts/issue", "value": issue}])

with_label(x, name) := json.patch(x, [{"op": "replace", "path": "/input/label", "value": name}])

with_size(x, n) := json.patch(x, [{"op": "replace", "path": "/plan/size", "value": n}])

pull := object.union(open_issue, {"pull_request": {"$redacted": "hash"}})

closed_issue := object.union(open_issue, {"state": "closed"})

denied(x) := {v.rule | some v in github.deny with input as x}

approvals(x) := {r.rule | some r in github.require_approval with input as x}

test_clean_label_is_allowed if {
	d := data.sefra.decision with input as label
	d.allow
	count(d.deny) == 0
	count(d.require_approval) == 0
}

test_clean_read_is_allowed if {
	d := data.sefra.decision with input as read
	d.allow
	count(d.deny) == 0
	count(d.require_approval) == 0
}

test_close_decision_needs_a_maintainer if {
	d := data.sefra.decision with input as close
	d.allow
	count(d.deny) == 0
	some r in d.require_approval
	r.approver.role == "maintainer"
	r.distinct_from_requester == true
}

test_agents_allowed_ if github.allow with input as close

test_agents_allowed_not_other_role if {
	x := json.patch(label, [{"op": "replace", "path": "/principal/roles", "value": ["viewer"]}])
	not github.allow with input as x
}

test_agents_allowed_not_other_intent if {
	x := json.patch(label, [{"op": "replace", "path": "/intent/type", "value": "github.delete_issue"}])
	not github.allow with input as x
}

test_issue_not_found_label if "github.issue_not_found" in denied(with_issue(label, null))

test_issue_not_found_close if "github.issue_not_found" in denied(with_issue(close, null))

test_issue_not_found_read if "github.issue_not_found" in denied(with_issue(read, null))

test_issue_not_found_not_existing if not "github.issue_not_found" in denied(label)

test_issue_not_found_not_while_unresolved if {
	x := json.patch(label, [{"op": "remove", "path": "/facts/issue"}])
	not "github.issue_not_found" in denied(x)
}

test_pull_request_label if "github.pull_request" in denied(with_issue(label, pull))

test_pull_request_close if "github.pull_request" in denied(with_issue(close, pull))

test_pull_request_read if "github.pull_request" in denied(with_issue(read, pull))

test_pull_request_not_issue if not "github.pull_request" in denied(label)

test_pull_request_not_while_unresolved if {
	x := json.patch(close, [{"op": "remove", "path": "/facts/issue"}])
	not "github.pull_request" in denied(x)
}

test_label_not_allowed_ if "github.label_not_allowed" in denied(with_label(label, "wontfix"))

test_label_not_allowed_not_listed_label if not "github.label_not_allowed" in denied(label)

test_label_not_allowed_not_close if not "github.label_not_allowed" in denied(close)

test_label_not_allowed_not_while_unresolved if {
	x := json.patch(label, [{"op": "remove", "path": "/input/label"}])
	not "github.label_not_allowed" in denied(x)
}

test_label_not_allowed_changed_setting if {
	x := with_label(label, "wontfix")
	not "github.label_not_allowed" in denied(x) with github.allowed_labels as {"wontfix"}
}

test_label_not_in_repository_ if {
	x := json.patch(label, [{"op": "replace", "path": "/facts/repo_label", "value": null}])
	"github.label_not_in_repository" in denied(x)
}

test_label_not_in_repository_not_existing if not "github.label_not_in_repository" in denied(label)

test_label_not_in_repository_not_while_unresolved if {
	x := json.patch(label, [{"op": "remove", "path": "/facts/repo_label"}])
	not "github.label_not_in_repository" in denied(x)
}

test_label_already_present_ if "github.label_already_present" in denied(with_label(label, "question"))

test_label_already_present_other_case if {
	x := with_issue(label, object.union(open_issue, {"labels": [{"name": "Bug"}]}))
	"github.label_already_present" in denied(x)
}

test_label_already_present_not_absent if not "github.label_already_present" in denied(label)

test_label_already_present_not_close if not "github.label_already_present" in denied(close)

test_already_closed_ if "github.already_closed" in denied(with_issue(close, closed_issue))

test_already_closed_unknown_state if {
	x := with_issue(close, object.union(open_issue, {"state": "archived"}))
	"github.already_closed" in denied(x)
}

test_already_closed_not_open if not "github.already_closed" in denied(close)

test_already_closed_not_label if not "github.already_closed" in denied(with_issue(label, closed_issue))

test_already_closed_not_while_unresolved if {
	x := json.patch(close, [{"op": "remove", "path": "/facts/issue"}])
	not "github.already_closed" in denied(x)
}

unresolved(x) := json.patch(x, [{"op": "replace", "path": "/unresolved/input", "value": ["/issue_number"]}])

duplicate(x) := json.patch(x, [{"op": "replace", "path": "/facts/sefra/duplicates_24h", "value": 1}])

test_unresolved_target_close if "github.unresolved_target" in denied(unresolved(close))

test_unresolved_target_label if "github.unresolved_target" in denied(unresolved(label))

test_unresolved_target_not_resolved if not "github.unresolved_target" in denied(close)

test_unresolved_target_not_read if not "github.unresolved_target" in denied(unresolved(read))

test_duplicate_close if "github.duplicate" in denied(duplicate(close))

test_duplicate_label if "github.duplicate" in denied(duplicate(label))

test_duplicate_not_first if not "github.duplicate" in denied(close)

test_duplicate_not_read if not "github.duplicate" in denied(duplicate(read))

test_plan_too_large_ if "github.plan_too_large" in denied(with_size(label, 6))

test_plan_too_large_not_at_limit if not "github.plan_too_large" in denied(with_size(label, 5))

test_close_approval_ if "github.close_approval" in approvals(close)

test_close_approval_not_label if not "github.close_approval" in approvals(label)

test_close_approval_not_read if not "github.close_approval" in approvals(read)
