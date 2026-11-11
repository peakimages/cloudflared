# Security

This page outlines what is in scope, our support policy and how to report vulnerabilities.

## Scope

Report a vulnerability to the project that maintains the affected code:

- **The image** is built in this repository: the Dockerfile and its build settings, the root filesystem and the workflows that test and publish it. Report it here, see [Reporting a Vulnerability](#reporting-a-vulnerability).
- **cloudflared** is maintained at [cloudflare/cloudflared](https://github.com/cloudflare/cloudflared). Report it to Cloudflare, see its [security policy](https://github.com/cloudflare/cloudflared/security/policy). Every cloudflared release becomes a new image, usually within a day.
- **A Go module of cloudflared** is raised in the image once its fix is released, see [PATCHES.md](PATCHES.md). Report it to the project of the module.
- **Go, Alpine and the CA bundle** are pinned in the Dockerfile. Report it to them, the fix reaches the image with its next release.

## Support Policy

Below you can find the support status for different versions of the image. The image version is the `v` part of an image tag, `peakimages/cloudflared:2026.11.0-v0.1.0` is image version `v0.1.0`.

| Version | Supported          | Support Status     |
| ------- | ------------------ | ------------------ |
| **1.x** | :white_check_mark: | Unreleased         |
| **0.x** | :white_check_mark: | Active Development |

Immutable tags such as `2026.11.0-v0.1.0` and `2026.11.0-fips-v0.1.0` are never rebuilt. A fix ships as a new image version, and the floating tags `2026.11.0`, `2026.11`, `2026` and `latest`, and the same tags with `-fips`, move to it. Deployments that pin an immutable tag receive fixes by moving to the newer tag.

## Reporting a Vulnerability

If you find a security vulnerability in a currently supported version, please follow these steps:

1. **DO NOT** disclose the vulnerability publicly.
2. Report it via [GitHub Security Advisories](https://github.com/peakimages/cloudflared/security/advisories/new).
3. Include in your report:
   - **Explanation:** Detailed explanation of the vulnerability.
   - **Affected Versions:** Which image tags are affected.
   - **Reproduction:** Clear steps to reproduce the vulnerability.
   - **Impact:** Assessment of the potential impact of the vulnerability.
