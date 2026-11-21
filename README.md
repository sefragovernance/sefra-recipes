# Sefra recipes

Ready-made bundles for [Sefra](https://sefra.io), a governance gateway between AI agents and the systems they change. Each recipe is a starting point: copy it, edit the rules and thresholds, and apply it. After you copy it, it is yours.

Running a recipe needs Sefra, which is available through a [pilot request](https://sefra.io/contact). The packs for Stripe and GitHub need a Sefra version that supports `success_when` on compensation.

## Catalogue

| Pack | Governs | Live check |
|---|---|---|
| [For Stripe](packs/stripe/) | Card charges and refunds, test mode only | Passed 2026-11-21 |
| [For GitHub](packs/github/) | Reading, labelling and closing issues in one repository | Passed 2026-11-21 |
| [For Jira](packs/jira/) | Reading and labelling issues in one project | Passed 2026-11-21 |

A pack counts as published only when its live check has passed against the vendor's sandbox.

## Layout

```
packs/<system>/
  README.md     what it governs, how to use it, what the live system taught us
  bundle/       a complete Sefra bundle
```

## Use a pack

```sh
sefra bundle test packs/stripe/bundle
sefra bundle apply packs/stripe/bundle
```

## Licence

Apache-2.0. See [LICENSE](LICENSE). Vendor names identify the systems a recipe works with and imply no partnership or endorsement.
