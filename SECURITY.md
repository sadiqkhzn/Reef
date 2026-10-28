# Security Policy

## Supported versions

Only the latest release of Reef is actively supported.

## Reporting a vulnerability

If you find a security issue, please email **sadiqkhan795@gmail.com** with the
details. Please do not open a public issue for security problems.

You can expect:

- Acknowledgement within 72 hours.
- A fix or mitigation plan within 7 days for high severity issues.
- Credit in the release notes if you would like it.

## Scope

Reef runs entirely on your Mac. It has no accounts and makes no network calls
of its own. Reportable issues include:

- Any undisclosed network traffic (there should be none).
- Any file read or write outside the app's own container and the paths a
  feature clearly needs.
- Any way the overlay can be used to capture input meant for another app.
