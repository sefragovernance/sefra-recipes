# Rules of this pack for Stripe. Edit the four constants to fit your business; they
# start strict on purpose.
#
# Allow on what is known at submission (principal, intent type). Data-dependent
# constraints are deny rules, which do not fire while a value they read is still
# unresolved at pre-flight.
package policies.payments

max_charge_minor := 100000 # 1,000.00: no larger charge

approval_charge_minor := 50000 # 500.00: a finance approver from this amount

max_refund_minor := 100000 # 1,000.00: no larger refund

approver_role := "finance_approver"

intents := {"payments.charge_card", "payments.refund_payment"}

# payments.agents_allowed
allow if {
	"payments_agent" in input.principal.roles
	input.intent.type in intents
}

# payments.charge_limit
deny contains {
	"rule": "payments.charge_limit",
	"message": "The charge is above the largest one this bundle allows.",
	"path": "/amount_minor",
	"actual": input.input.amount_minor,
	"limit": max_charge_minor,
	"hint": "Charge a smaller amount.",
} if {
	input.intent.type == "payments.charge_card"
	input.input.amount_minor > max_charge_minor
}

# payments.refund_limit
deny contains {
	"rule": "payments.refund_limit",
	"message": "The refund is above the largest one this bundle allows.",
	"path": "/amount_minor",
	"actual": input.input.amount_minor,
	"limit": max_refund_minor,
	"hint": "Refund a smaller amount, or ask an operator.",
} if {
	input.intent.type == "payments.refund_payment"
	input.input.amount_minor > max_refund_minor
}

# payments.duplicate
deny contains {
	"rule": "payments.duplicate",
	"message": "The same payment action was accepted in the last 24 hours.",
	"actual": input.facts.sefra.duplicates_24h,
	"limit": 0,
	"hint": "Check the earlier execution instead of repeating it.",
} if {
	input.intent.type in intents
	input.facts.sefra.duplicates_24h >= 1
}

# payments.large_charge
require_approval contains {
	"rule": "payments.large_charge",
	"message": sprintf("The charge of %d minor units is at least %d.", [input.input.amount_minor, approval_charge_minor]),
	"approver": {"role": approver_role},
	"distinct_from_requester": true,
} if {
	input.intent.type == "payments.charge_card"
	input.input.amount_minor >= approval_charge_minor
}

# payments.multiple_charges
require_approval contains {
	"rule": "payments.multiple_charges",
	"message": "A plan with more than one charge could split a large one.",
	"approver": {"role": approver_role},
	"distinct_from_requester": true,
} if {
	input.intent.type == "payments.charge_card"
	count([i | some i in input.plan.intents; i == "payments.charge_card"]) > 1
}

# payments.refund_approval
require_approval contains {
	"rule": "payments.refund_approval",
	"message": "A refund cannot be undone, so a person approves every one.",
	"approver": {"role": approver_role},
	"distinct_from_requester": true,
} if {
	input.intent.type == "payments.refund_payment"
}
