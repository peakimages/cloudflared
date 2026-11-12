# Changelog

All notable changes to this project will be documented in this file. cloudflared version bumps are not listed, every release tag names the cloudflared version it ships.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v0.1.0] - 2026-11-12

### Added

- Minimal and hardened cloudflared image on `scratch`, compiled from the tagged source
  - The image runs as the `nonroot` user `65532`, with `cloudflared tunnel run` as the default command and the metrics port on `127.0.0.1`
  - The health check runs `cloudflared tunnel ready`
  - A patch can raise Go modules with a known vulnerability before Cloudflare does
  - The `fips` flavor has the certified Go FIPS 140-3 module
  - The platforms are `amd64`, `arm64`, `arm/v7`, `arm/v6`, `386`, `riscv64`, `ppc64le` and `s390x`

