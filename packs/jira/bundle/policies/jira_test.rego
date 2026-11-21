# For each rule, a test that fires it and a test that does not.
package policies.jira_test

import data.policies.jira

issue_key := sprintf("%s-7", [jira.project_key])

todo_issue := {
	"key": issue_key,
	"fields": {
		"project": {"key": jira.project_key},
		"status": {"name": "To Do"},
		"labels": ["needs-info"],
	},
}

offered := {"transitions": [
	{"id": "11", "isAvailable": true, "to": {"name": "To Do"}},
	{"id": "21", "isAvailable": true, "to": {"name": "In Progress"}},
	{"id": "41", "isAvailable": true, "to": {"name": "Done"}},
]}

label := {
	"phase": "step",
	"principal": {"id": "agent:jira", "type": "agent", "roles": ["jira_agent"]},
	"intent": {"type": "jira.add_label", "version": 1, "effect": "write", "irreversible": false},
	"input": {"issue_key": issue_key, "label": "triaged"},
	"facts": {"issue": todo_issue, "sefra": {"duplicates_24h": 0, "denials_10m": 0}},
	"unresolved": {"input": [], "facts": []},
	"plan": {"size": 1, "index": 0, "intents": ["jira.add_label"]},
	"env": {"time": "2026-11-21T10:15:00Z", "bundle_digest": "sha256:test"},
}

start := json.patch(label, [
	{"op": "replace", "path": "/intent/type", "value": "jira.start_work"},
	{"op": "replace", "path": "/input", "value": {"issue_key": issue_key}},
	{"op": "add", "path": "/facts/transitions", "value": offered},
	{"op": "replace", "path": "/plan/intents", "value": ["jira.start_work"]},
])

read := json.patch(label, [
	{"op": "replace", "path": "/intent", "value": {"type": "jira.get_issue", "version": 1, "effect": "read", "irreversible": false}},
	{"op": "replace", "path": "/input", "value": {"issue_key": issue_key}},
	{"op": "replace", "path": "/plan/intents", "value": ["jira.get_issue"]},
])

with_issue(x, issue) := json.patch(x, [{"op": "replace", "path": "/facts/issue", "value": issue}])

with_label(x, name) := json.patch(x, [{"op": "replace", "path": "/input/label", "value": name}])

with_size(x, n) := json.patch(x, [{"op": "replace", "path": "/plan/size", "value": n}])

with_status(name) := json.patch(todo_issue, [{"op": "replace", "path": "/fields/status/name", "value": name}])

with_transitions(ts) := json.patch(start, [{"op": "replace", "path": "/facts/transitions", "value": {"transitions": ts}}])

without_fact(x, name) := json.patch(x, [{"op": "remove", "path": sprintf("/facts/%s", [name])}])

moved_project := json.patch(todo_issue, [{"op": "replace", "path": "/fields/project/key", "value": "OTHER"}])

moved_key := json.patch(todo_issue, [{"op": "replace", "path": "/key", "value": "OTHER-3"}])

unresolved(x) := json.patch(x, [{"op": "replace", "path": "/unresolved/input", "value": ["/issue_key"]}])

duplicate(x) := json.patch(x, [{"op": "replace", "path": "/facts/sefra/duplicates_24h", "value": 1}])

denied(x) := {v.rule | some v in jira.deny with input as x}

approvals(x) := {r.rule | some r in jira.require_approval with input as x}

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

test_start_decision_needs_a_project_lead if {
	d := data.sefra.decision with input as start
	d.allow
	count(d.deny) == 0
	some r in d.require_approval
	r.approver.role == "project_lead"
	r.distinct_from_requester == true
}

test_agents_allowed_ if jira.allow with input as start

test_agents_allowed_not_other_role if {
	x := json.patch(label, [{"op": "replace", "path": "/principal/roles", "value": ["viewer"]}])
	not jira.allow with input as x
}

test_agents_allowed_not_other_intent if {
	x := json.patch(label, [{"op": "replace", "path": "/intent/type", "value": "jira.delete_issue"}])
	not jira.allow with input as x
}

test_issue_not_found_label if "jira.issue_not_found" in denied(with_issue(label, null))

test_issue_not_found_start if "jira.issue_not_found" in denied(with_issue(start, null))

test_issue_not_found_read if "jira.issue_not_found" in denied(with_issue(read, null))

test_issue_not_found_not_existing if not "jira.issue_not_found" in denied(label)

test_issue_not_found_not_while_unresolved if not "jira.issue_not_found" in denied(without_fact(label, "issue"))

test_wrong_project_moved_label if "jira.wrong_project" in denied(with_issue(label, moved_project))

test_wrong_project_moved_start if "jira.wrong_project" in denied(with_issue(start, moved_project))

test_wrong_project_moved_read if "jira.wrong_project" in denied(with_issue(read, moved_project))

test_wrong_project_new_key if "jira.wrong_project" in denied(with_issue(label, moved_key))

test_wrong_project_input_key if {
	x := json.patch(read, [{"op": "replace", "path": "/input/issue_key", "value": "OTHER-7"}])
	"jira.wrong_project" in denied(with_issue(x, object.union(todo_issue, {"key": "OTHER-7"})))
}

test_wrong_project_longer_project_name if {
	longer := sprintf("%sX-7", [jira.project_key])
	x := json.patch(read, [{"op": "replace", "path": "/input/issue_key", "value": longer}])
	"jira.wrong_project" in denied(with_issue(x, object.union(todo_issue, {"key": longer})))
}

test_wrong_project_not_own_issue if not "jira.wrong_project" in denied(label)

test_wrong_project_not_when_missing if not "jira.wrong_project" in denied(with_issue(label, null))

test_wrong_project_not_while_unresolved if {
	x := json.patch(without_fact(start, "issue"), [{"op": "remove", "path": "/input/issue_key"}])
	not "jira.wrong_project" in denied(x)
}

test_wrong_project_changed_setting if {
	x := with_issue(label, moved_project)
	y := json.patch(x, [
		{"op": "replace", "path": "/input/issue_key", "value": "OTHER-7"},
		{"op": "replace", "path": "/facts/issue/key", "value": "OTHER-7"},
	])
	not "jira.wrong_project" in denied(y) with jira.project_key as "OTHER"
}

test_label_not_allowed_ if "jira.label_not_allowed" in denied(with_label(label, "wontfix"))

test_label_not_allowed_other_case if "jira.label_not_allowed" in denied(with_label(label, "Triaged"))

test_label_not_allowed_not_listed_label if not "jira.label_not_allowed" in denied(label)

test_label_not_allowed_not_start if not "jira.label_not_allowed" in denied(start)

test_label_not_allowed_not_while_unresolved if {
	x := json.patch(label, [{"op": "remove", "path": "/input/label"}])
	not "jira.label_not_allowed" in denied(x)
}

test_label_not_allowed_changed_setting if {
	x := with_label(label, "wontfix")
	not "jira.label_not_allowed" in denied(x) with jira.allowed_labels as {"wontfix"}
}

test_label_already_present_ if "jira.label_already_present" in denied(with_label(label, "needs-info"))

test_label_already_present_not_absent if not "jira.label_already_present" in denied(label)

test_label_already_present_not_other_case if {
	x := with_issue(label, json.patch(todo_issue, [{"op": "replace", "path": "/fields/labels", "value": ["Triaged"]}]))
	not "jira.label_already_present" in denied(x)
}

test_label_already_present_not_start if not "jira.label_already_present" in denied(start)

test_not_in_expected_status_in_progress if "jira.not_in_expected_status" in denied(with_issue(start, with_status("In Progress")))

test_not_in_expected_status_done if "jira.not_in_expected_status" in denied(with_issue(start, with_status("Done")))

test_not_in_expected_status_unknown if "jira.not_in_expected_status" in denied(with_issue(start, with_status("Blocked")))

test_not_in_expected_status_not_to_do if not "jira.not_in_expected_status" in denied(start)

test_not_in_expected_status_not_label if not "jira.not_in_expected_status" in denied(with_issue(label, with_status("Done")))

test_not_in_expected_status_not_while_unresolved if not "jira.not_in_expected_status" in denied(without_fact(start, "issue"))

test_workflow_mismatch_no_forward if {
	x := with_transitions([{"id": "11", "isAvailable": true, "to": {"name": "To Do"}}])
	"jira.workflow_mismatch" in denied(x)
}

test_workflow_mismatch_no_undo if {
	x := with_transitions([{"id": "21", "isAvailable": true, "to": {"name": "In Progress"}}])
	"jira.workflow_mismatch" in denied(x)
}

test_workflow_mismatch_id_leads_elsewhere if {
	x := with_transitions([
		{"id": "11", "isAvailable": true, "to": {"name": "To Do"}},
		{"id": "21", "isAvailable": true, "to": {"name": "Done"}},
	])
	"jira.workflow_mismatch" in denied(x)
}

test_workflow_mismatch_not_available if {
	x := with_transitions([
		{"id": "11", "isAvailable": true, "to": {"name": "To Do"}},
		{"id": "21", "isAvailable": false, "to": {"name": "In Progress"}},
	])
	"jira.workflow_mismatch" in denied(x)
}

test_workflow_mismatch_null_fact if {
	x := json.patch(start, [{"op": "replace", "path": "/facts/transitions", "value": null}])
	"jira.workflow_mismatch" in denied(x)
}

test_workflow_mismatch_not_matching if not "jira.workflow_mismatch" in denied(start)

test_workflow_mismatch_not_label if not "jira.workflow_mismatch" in denied(label)

test_workflow_mismatch_not_while_unresolved if not "jira.workflow_mismatch" in denied(without_fact(start, "transitions"))

test_workflow_mismatch_changed_setting if {
	x := with_transitions([
		{"id": "5", "isAvailable": true, "to": {"name": "To Do"}},
		{"id": "6", "isAvailable": true, "to": {"name": "In Progress"}},
	])
	not "jira.workflow_mismatch" in denied(x) with jira.start_transition as "6" with jira.undo_transition as "5"
}

test_unresolved_target_start if "jira.unresolved_target" in denied(unresolved(start))

test_unresolved_target_label if "jira.unresolved_target" in denied(unresolved(label))

test_unresolved_target_not_resolved if not "jira.unresolved_target" in denied(start)

test_unresolved_target_not_read if not "jira.unresolved_target" in denied(unresolved(read))

test_duplicate_start if "jira.duplicate" in denied(duplicate(start))

test_duplicate_label if "jira.duplicate" in denied(duplicate(label))

test_duplicate_not_first if not "jira.duplicate" in denied(start)

test_duplicate_not_read if not "jira.duplicate" in denied(duplicate(read))

test_plan_too_large_ if "jira.plan_too_large" in denied(with_size(label, 6))

test_plan_too_large_not_at_limit if not "jira.plan_too_large" in denied(with_size(label, 5))

test_start_work_approval_ if "jira.start_work_approval" in approvals(start)

test_start_work_approval_not_label if not "jira.start_work_approval" in approvals(label)

test_start_work_approval_not_read if not "jira.start_work_approval" in approvals(read)
