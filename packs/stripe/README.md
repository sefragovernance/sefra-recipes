# Sefra pack for Stripe

Governs the card charges and refunds an AI agent makes through Stripe. **Test mode only.**

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
| `payments.multiple_charges` | A finance approver for any plan with more than one charge |
| `payments.refund_limit` | No refund above 1,000.00 |
| `payments.refund_approval` | A person approves every refund |
| `payments.duplicate` | The same action is refused for 24 hours. An earlier execution that was rejected, failed or rolled back does not count, so an action that was undone can be repeated at once |

The amounts are constants at the top of `bundle/policies/payments.rego`. They start strict on purpose and are compared in minor units, whatever the currency.

## Set up

The pack needs Sefra 0.1.0-rc.2 or later.

1. Store a Stripe test key in your secret manager and map it to the name `stripe_secret_key` in your Sefra configuration.
2. Give your agent the role `payments_agent`, and your approvers the role `finance_approver`.
3. Run `sefra bundle test packs/stripe/bundle`, then `sefra bundle apply packs/stripe/bundle`.

The connector refuses any key that is not a test key. That is the guard for refunds, because Stripe refund answers carry no live-mode field. It also does not trust a charge answered as live, or a refund answered as failed. Going live is a deliberate edit of `secret_prefixes` and `fail_closed_on` in `bundle/connectors.yaml`.

## What the live API taught us

From running this pack against the Stripe sandbox:

- Stripe refused `payment_method_types` and `error_on_requires_action` with a 400, so the charge uses `automatic_payment_methods` without redirects.
- A `200` can mean a payment that still needs the customer. The output schema requires `status: succeeded`, so such an answer goes to an operator instead of passing as paid.
- There is no probe for an unclear charge, because search at Stripe is eventually consistent and could call a real charge absent.
- A refund can answer `200` and still be `pending`, and can fail later. This pack treats only `succeeded` as done.
- Refund answers have no `livemode` field, so a live-mode check on the answer cannot protect a refund.

## Known limits

- **A rollback refund that is still `pending` goes to an operator,** even if it finishes later. Sefra counts it as undone only when Stripe answers `succeeded`. This relies on `success_when` on compensation, in Sefra 0.1.0-rc.2 and later.
- **Refund limits apply per call.** Several approved partial refunds can exceed the limit in total. A person approves each one.
- **Limits compare minor units, not currencies,** and the approval summary does not show the refund's currency.
- **Charges split across separate executions** are not added up.
- A refund that Stripe fails after reporting success is not tracked.

Stripe is a trademark of Stripe, Inc. This pack is not affiliated with or endorsed by Stripe.
