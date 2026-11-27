<p align="center">
  <a href="https://sefra.io">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset=".github/assets/lockup-white.svg">
      <img src=".github/assets/lockup-black.svg" alt="Sefra" height="48">
    </picture>
  </a>
</p>

<h1 align="center">Sefra recipes</h1>

<p align="center">
  Ready-made bundles that govern how AI agents write to Stripe, GitHub and Jira.
</p>

<p align="center">
  <a href="https://sefra.io">Website</a> ·
  <a href="https://docs.sefra.io/">Documentation</a> ·
  <a href="https://docs.sefra.io/recipes/">Recipes in the docs</a> ·
  <a href="https://sefra.io/blog">Blog</a> ·
  <a href="https://sefra.io/contact">Request a pilot</a>
</p>

---

## What Sefra is

[Sefra](https://sefra.io) is the write gate for AI agents: a self-hosted governance gateway between AI agents and the systems of record they change. Agents submit typed intents. Sefra checks each one with deterministic policy on live facts, holds the risky ones for a person, executes with its own credentials, undoes completed steps when a later one fails, and records every decision in a hash-chained audit trail. [How it works](https://sefra.io/product).

## What a recipe is

A recipe is a complete Sefra bundle for one system: the intents an agent may submit, the policies that decide them, the grants, the limits and the connector. Each one is a starting point. Copy it, edit the rules and thresholds, and apply it. After you copy it, it is yours.

Running a recipe needs Sefra 0.1.0-rc.2 or later. Sefra is available through a [pilot request](https://sefra.io/contact). Every pack passes `sefra bundle test` on that release.

## Catalogue

| Pack | Governs | Overview | Set-up guide | Live check |
|---|---|---|---|---|
| [For Stripe](packs/stripe/) | Card charges and refunds, test mode only | [sefra.io](https://sefra.io/solutions/integrations/stripe) | [Docs](https://docs.sefra.io/recipes/stripe/) | Passed 2026-11-21 |
| [For GitHub](packs/github/) | Reading, labelling and closing issues in one repository | [sefra.io](https://sefra.io/solutions/integrations/github) | [Docs](https://docs.sefra.io/recipes/github/) | Passed 2026-11-21 |
| [For Jira](packs/jira/) | Reading and labelling issues in one project | [sefra.io](https://sefra.io/solutions/integrations/jira) | [Docs](https://docs.sefra.io/recipes/jira/) | Passed 2026-11-21 |

A pack counts as published only when its live check has passed against the vendor's sandbox.

## Use a pack

```sh
sefra bundle test packs/stripe/bundle
sefra bundle apply packs/stripe/bundle
```

New to Sefra? Start with the [quickstart](https://docs.sefra.io/get-started/quickstart/), then read how [intents](https://docs.sefra.io/build/manifests/) and [policies](https://docs.sefra.io/build/policies/) are written before you edit a pack.

## Layout

```
packs/<system>/
  README.md     what it governs, how to use it, what the live system taught us
  bundle/       a complete Sefra bundle
    connectors.yaml
    grants.yaml
    limits.yaml
    intents/
    policies/
```

## Further reading

- [What is a write gate for AI agents?](https://sefra.io/blog/what-is-a-write-gate)
- [What a prompt-injected agent can do with no keys](https://sefra.io/blog/prompt-injected-agent-no-keys)
- [Agent security is now a first-class requirement](https://sefra.io/blog/agent-security-first-class)
- [Security architecture](https://sefra.io/security)

## Licence

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). To report a security problem, see [SECURITY.md](SECURITY.md); to contribute, [CONTRIBUTING.md](CONTRIBUTING.md). Vendor names identify the systems a recipe works with and imply no partnership or endorsement.
