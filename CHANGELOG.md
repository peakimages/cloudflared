# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v2026.11.1-v0.1.3] - 2026-11-22

### Fixed

- Missing `SSL_CERT_FILE` and `SSL_CERT_DIR` environment variables
  - `SSL_CERT_FILE` points at the CA bundle of the image, `/etc/ssl/certs/ca-certificates.crt`, as in the official image, and lets users set another bundle at runtime
  - `SSL_CERT_DIR` points at `/etc/ssl/certs`, the directory Go reads by default, and lets users set other directories at runtime
- Release notes of a cloudflared update linking to its GitHub release, which only lists checksums
  - The link points at `RELEASE_NOTES` at the tag of the cloudflared release

### Maintenance

- Listed every release under its full tag in `CHANGELOG.md`
  - Every cloudflared update has a section of its own, not only every version of the image

## [v2026.11.1-v0.1.2] - 2026-11-18

### Changed

- cloudflared from v2026.11.0 to v2026.11.1, see its [release notes](https://github.com/cloudflare/cloudflared/blob/refs/tags/2026.11.1/RELEASE_NOTES)
  - The patch of `go.opentelemetry.io/otel/sdk` and `go.opentelemetry.io/otel/trace` is dropped, cloudflared v2026.11.1 requires the fixed version

## [v2026.11.0-v0.1.2] - 2026-11-17

### Security

- Patched two OpenTelemetry modules of cloudflared with a known vulnerability
  - `go.opentelemetry.io/otel/sdk` and `go.opentelemetry.io/otel/trace` from v1.45.0 to v1.47.0 for [CVE-2026-128085](https://www.cve.org/CVERecord?id=CVE-2026-128085)

## [v2026.11.0-v0.1.1] - 2026-11-13

### Security

- Patched two Go modules of cloudflared with known vulnerabilities
  - `golang.org/x/net` from v0.61.0 to v0.62.0 for [CVE-2026-78661](https://www.cve.org/CVERecord?id=CVE-2026-78661) and [CVE-2026-97045](https://www.cve.org/CVERecord?id=CVE-2026-97045)
  - `golang.org/x/crypto` from v0.58.0 to v0.59.0 for [GO-2026-5932](https://pkg.go.dev/vuln/GO-2026-5932)

## [v2026.11.0-v0.1.0] - 2026-11-12

### Added

- Minimal and hardened cloudflared image on `scratch`, compiled from the tagged source
  - The image runs as the `nonroot` user `65532`, with `cloudflared tunnel run` as the default command and the metrics port on `127.0.0.1`
  - The health check runs `cloudflared tunnel ready`
  - A patch can raise Go modules with a known vulnerability before Cloudflare does
  - The `fips` flavor has the certified Go FIPS 140-3 module
  - The platforms are `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `riscv64`, `ppc64le` and `s390x`

