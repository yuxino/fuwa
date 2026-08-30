# Security Policy

## Supported versions

Security fixes are provided for the latest released minor version of Fuwa.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Older versions | No |

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting option on the [Fuwa Security page](https://github.com/yuxino/fuwa/security) when available. Include:

- the affected Fuwa version, operating system, version, and architecture;
- clear reproduction steps;
- the security impact and any relevant logs or proof of concept;
- whether the issue exposes window content, weakens a privacy-boundary cleanup, expands macOS Accessibility behavior, or changes the Windows DWM/Win32 safety boundary.

Do not include private screenshots, captured window contents, credentials, or personal data unless a maintainer has provided a secure channel. Do not open a public issue with vulnerability details. If private reporting is unavailable, open a minimal public issue asking for a private contact method without describing the vulnerability.

You can expect an acknowledgement within 7 days. The maintainers will validate the report, coordinate a fix and disclosure timeline, and credit reporters who want attribution.

## Scope

Particularly relevant reports include unintended retention or disclosure of window pixels, incorrect handling of lock/sleep/user-switch boundaries, unsafe use of Accessibility, input injection, use of private APIs, or supply-chain issues in release artifacts.

Expected macOS permission prompts, inability to mirror DRM or secure system windows, Windows foreground/topmost restrictions, and limitations already documented in the README are generally not vulnerabilities unless they can be used to bypass a security boundary.
