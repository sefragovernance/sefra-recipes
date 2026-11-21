# Stripe pack

Governs an AI agent's card charges and refunds in Stripe. **Test mode only**, and its live check has not passed yet.

## What it does

| Intent | Effect | If something fails |
|---|---|---|
| `payments.charge_card` | Charges a card | Refunded in full when a later step of the plan fails |
| `payments.refund_payment` | Refunds a payment, in full or in part | Cannot be undone, so it must be the last step of a plan |

## Rules

| Rule | Default |
|---|---|
| `payments.charge_limit` | No charge above 1,000.00 |
| `payments.large_charge` | A finance approver from 500.00 |
| `payments.refund_limit` | No refund above 1,000.00 |
| `payments.refund_approval` | A person approves every refund |
| `payments.duplicate` | The same action is refused for 24 hours |

The amounts are constants at the top of `bundle/policies/payments.rego`. They start strict on purpose and are compared in minor units, whatever the currency.

## Set up

1. Store a Stripe test key in your secret manager and map it to the name `stripe_secret_key` in your Sefra configuration.
2. Give your agent the role `payments_agent`, and your approvers the role `finance_approver`.
3. Run `sefra bundle test packs/stripe/bundle`, then `sefra bundle apply packs/stripe/bundle`.

The connector refuses any key that is not a test key and does not trust an answer marked live. Going live is a deliberate edit of `secret_prefixes` and `fail_closed_on` in `bundle/connectors.yaml`.

## What the live API taught us

From Sefra's earlier run of the charge against Stripe's sandbox:

- Stripe refused `payment_method_types` and `error_on_requires_action` with a 400, so the charge uses `automatic_payment_methods` without redirects.
- A `200` can mean a payment that still needs the customer. The output schema requires `status: succeeded`, so such an answer goes to an operator instead of passing as paid.
- There is no probe for an unclear charge, because Stripe's search is eventually consistent and could call a real charge absent.

The refund intent has not been run against the live API yet.
