# For each rule, a test that fires it and a test that does not.
package policies.payments_test

import data.policies.payments

charge := {
	"phase": "step",
	"principal": {"id": "agent:payments", "type": "agent", "roles": ["payments_agent"]},
	"intent": {"type": "payments.charge_card", "version": 1, "effect": "write", "irreversible": false},
	"input": {"amount_minor": 1234, "currency": "eur", "payment_method": "pm_card_visa", "description": "test"},
	"facts": {"sefra": {"duplicates_24h": 0, "denials_10m": 0}},
	"unresolved": {"input": [], "facts": []},
	"plan": {"size": 1, "index": 0, "intents": ["payments.charge_card"]},
	"env": {"time": "2026-11-21T10:15:00Z", "bundle_digest": "sha256:test"},
}

refund := object.union(charge, {
	"intent": {"type": "payments.refund_payment", "version": 1, "effect": "write", "irreversible": true},
	"input": {"payment_intent": "pi_123", "amount_minor": 1234, "reason": "requested_by_customer"},
	"plan": {"size": 1, "index": 0, "intents": ["payments.refund_payment"]},
})

amount(x, n) := json.patch(x, [{"op": "replace", "path": "/input/amount_minor", "value": n}])

duplicate(x) := json.patch(x, [{"op": "replace", "path": "/facts/sefra/duplicates_24h", "value": 1}])

denied(x) := {v.rule | some v in payments.deny with input as x}

approvals(x) := {r.rule | some r in payments.require_approval with input as x}

test_clean_charge_is_allowed if {
	d := data.sefra.decision with input as charge
	d.allow
	count(d.deny) == 0
	count(d.require_approval) == 0
}

test_agents_allowed_ if payments.allow with input as refund

test_agents_allowed_not_other_role if {
	x := json.patch(charge, [{"op": "replace", "path": "/principal/roles", "value": ["viewer"]}])
	not payments.allow with input as x
}

test_agents_allowed_not_other_intent if {
	x := json.patch(charge, [{"op": "replace", "path": "/intent/type", "value": "payments.other"}])
	not payments.allow with input as x
}

test_charge_limit_ if "payments.charge_limit" in denied(amount(charge, 100001))

test_charge_limit_not_at_limit if not "payments.charge_limit" in denied(amount(charge, 100000))

test_charge_limit_not_refund if not "payments.charge_limit" in denied(amount(refund, 100001))

test_refund_limit_ if "payments.refund_limit" in denied(amount(refund, 100001))

test_refund_limit_not_at_limit if not "payments.refund_limit" in denied(amount(refund, 100000))

test_refund_limit_not_charge if not "payments.refund_limit" in denied(amount(charge, 100001))

test_duplicate_charge if "payments.duplicate" in denied(duplicate(charge))

test_duplicate_refund if "payments.duplicate" in denied(duplicate(refund))

test_duplicate_not_first if not "payments.duplicate" in denied(charge)

test_large_charge_ if "payments.large_charge" in approvals(amount(charge, 50000))

test_large_charge_not_below if not "payments.large_charge" in approvals(amount(charge, 49999))

test_large_charge_not_refund if not "payments.large_charge" in approvals(amount(refund, 50000))

test_refund_approval_ if "payments.refund_approval" in approvals(refund)

test_refund_approval_small if "payments.refund_approval" in approvals(amount(refund, 1))

test_refund_approval_not_charge if not "payments.refund_approval" in approvals(charge)
