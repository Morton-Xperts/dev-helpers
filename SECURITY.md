# Security Policy

## Supported Versions

Use this section to tell people about which versions of your project are
currently being supported with security updates.

| Version     | Supported          |
| ----------- | ------------------ |
| >= 0.22.22  | :white_check_mark: |
| < 0.22.22   | :x:                |

## Reporting a Vulnerability

Please do not create public issues for security vulnerabilities.

- Preferred: Use GitHub Private Vulnerability Reporting. In this repository, open the `Security` tab and click `Report a vulnerability` to start a private advisory with the maintainers.
- Alternative: If you cannot access that feature, open a new issue titled "Security: contact @rvajustin" without sensitive details and mention `@rvajustin`. We will follow up to establish a private channel and request the necessary information (affected versions, environment, impact, and a minimal reproduction, if available).
  - If issues are disabled: open a GitHub Discussion (if enabled) titled "Security: contact @rvajustin" with no sensitive details and mention `@rvajustin`.
  - If neither issues nor discussions are available: open a minimal pull request (e.g., a whitespace change to `SECURITY.md`) titled "Security: contact @rvajustin" with no sensitive details and mention `@rvajustin`. We will respond and coordinate a private channel.

### What to expect

- Acknowledgement within 3 business days.
- Initial assessment within 5 business days.
- Status updates at least every 7 days until resolution.

### Coordinated disclosure

- We follow a coordinated disclosure process. We aim to release a fix and publish an advisory before public disclosure. We will work with you on timing, taking into account severity and exploitability.
- If we cannot reproduce or determine the issue is out of scope, we will explain why and close the report.

### Remediation targets (non‑binding goals)

- Critical: target fix within 7 days
- High: target fix within 14 days
- Medium: target fix within 30 days
- Low: target fix within 90 days

We will backport fixes to supported versions (see table above) when feasible. If a code fix is not practical, we will document mitigations or workarounds.

### Credit

We gratefully credit reporters in release notes and advisories unless you prefer to remain anonymous.

### Scope and exclusions

In scope: vulnerabilities affecting the code and packages in this repository.

Out of scope (non‑exhaustive):
- Issues in third‑party dependencies or services not maintained here
- Social engineering, phishing, or physical attacks
- Denial‑of‑service, volumetric/resource‑exhaustion testing
- Automated scanning without a clear, actionable vulnerability
- Privacy violations, data exfiltration, or access to data you do not own

### Safe harbor

If you make a good‑faith effort to comply with this policy, test only against your own accounts and data, avoid service degradation, and do not compromise privacy, we will not pursue legal action or law enforcement investigation against you.

### CVEs and bounties

- CVEs: We will request CVE IDs via GitHub Security Advisories when appropriate.
- Bounties: We do not offer monetary bounties at this time.
