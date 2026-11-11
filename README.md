# cloudflared

[![Release](https://img.shields.io/github/actions/workflow/status/peakimages/cloudflared/release.yaml?branch=main&label=release)](https://github.com/peakimages/cloudflared/actions/workflows/release.yaml)
[![cloudflared](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fpeakimages%2Fcloudflared%2Fmain%2Fsrc%2Fupstream.json&query=%24.cloudflared.latest.version&label=cloudflared)](https://github.com/peakimages/cloudflared/releases)
[![License](https://img.shields.io/github/license/peakimages/cloudflared)](LICENSE)
[![Docker pulls](https://img.shields.io/docker/pulls/peakimages/cloudflared)](https://hub.docker.com/r/peakimages/cloudflared)
[![Image size](https://img.shields.io/docker/image-size/peakimages/cloudflared/latest?arch=amd64)](https://hub.docker.com/r/peakimages/cloudflared)

## Introduction

A minimal and hardened image of cloudflared, the Cloudflare Tunnel client. It is compiled from source, a third of the size of the official image and patched without waiting for a cloudflared release, with a FIPS 140-3 variation and builds for eight platforms.

> [!IMPORTANT]
> `peakimages/cloudflared` is currently **v0** and subject to breaking changes prior to `v1.0.0`. Pin to a specific version like `peakimages/cloudflared:2026.11.0-v0.1.0` to avoid breaking changes.

### What Makes This Image Different?

cloudflared is one Go binary that needs nothing but CA certificates. This image compiles it from the release tag, ships it on `scratch`, keeps its metrics port private and patches Go or a Go module without waiting for Cloudflare.

- ✅ Secure by Default: Runs as unprivileged user `65532` on `scratch`, no shell, no package manager, read-only root filesystem supported
- ✅ Private Metrics: The metrics port listens on `127.0.0.1`, it also serves the ingress rules, diagnostics and profiles
- ✅ Smaller: Compiled from the release tag without symbol table and debug information, a third of the size of the official image
- ✅ Patched Dependencies: A Go module with a known vulnerability is raised before Cloudflare releases the update, see [PATCHES.md](PATCHES.md)
- ✅ FIPS 140-3: A `fips` variation built with Go's certified cryptographic module
- ✅ Verified Source: The release tag must point to the pinned commit and every Go module must match `go.sum` before each compilation
- ✅ Modern Architecture: Native health check, OCI labels, reproducible builds, provenance and SBOM attestations
- ✅ Always Current: GitHub is checked twice a day and new cloudflared releases become new images
- ✅ Multi-Architecture: Builds for `linux/amd64`, `linux/arm64`, `linux/arm/v7`, `linux/arm/v6`, `linux/386`, `linux/riscv64`, `linux/ppc64le` and `linux/s390x`
- ✅ Tested: Every release is tested on all eight platforms before it is published

## Comparison

To see a comparison of this image with other popular cloudflared Docker images, see [docs/comparison.md](docs/comparison.md).

## Getting Started

Create a tunnel in the Cloudflare dashboard under Zero Trust, Networks, Tunnels, and copy its token. The routes of the tunnel are set in the dashboard, the container only needs the token and runs `cloudflared tunnel run` by default.

> [!NOTE]
> The layers of the image are compressed with zstd, pulling it needs Docker Engine 23.0 or later.

### Docker

```sh
docker run -d --name cloudflared --read-only -e TUNNEL_TOKEN=your-token peakimages/cloudflared
```

### Docker Compose

Add the tunnel next to the service it publishes, which it reaches by its service name:

```yaml
services:
  cloudflared:
    image: peakimages/cloudflared:2026.11.0-v0.1.0
    read_only: true
    restart: unless-stopped
    environment:
      TUNNEL_TOKEN: your-token

  app:
    image: your-app
```

## Available Image Variations

All tags follow this pattern, the default variation leaves out `-{{variation}}`:

```sh
peakimages/cloudflared:{{cloudflared-version}}-{{variation}}-v{{image-version}}
```

| Variation | Best For                                                    | Example                                        |
| --------- | ----------------------------------------------------------- | ---------------------------------------------- |
| default   | Every tunnel, from Docker Compose to Kubernetes             | `peakimages/cloudflared:2026.11.0-v0.1.0`      |
| `fips`    | Environments that require FIPS 140-3 validated cryptography | `peakimages/cloudflared:2026.11.0-fips-v0.1.0` |

The `fips` variation only uses approved algorithms, TLS with AES-GCM and `X25519MLKEM768` or the NIST curves for the key exchange, and connects to the Cloudflare edge like the default.

### Tags

| Tag                                             | Meaning                                                                          |
| ----------------------------------------------- | -------------------------------------------------------------------------------- |
| `2026.11.0-v0.1.0`, `2026.11.0-fips-v0.1.0`     | Immutable: cloudflared 2026.11.0 built as image v0.1.0, never rebuilt            |
| `2026.11.0`, `2026.11`, `2026`                  | Newest release of that cloudflared version, month or year                        |
| `latest`                                        | Newest release                                                                   |
| `preview`                                       | Newest prerelease, like `2026.11.0-v0.2.0-beta.1`, until its release replaces it |
| `2026.11.0-fips`, `latest-fips`, `preview-fips` | The same for the `fips` variation                                                |

### Registries

| 📦 Registry                                                                                       | 🐳 Image                                                                                                                                   |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| [Docker Hub](https://hub.docker.com/r/peakimages/cloudflared)                                     | ![peakimages/cloudflared](https://img.shields.io/github/v/release/peakimages/cloudflared?label=peakimages%2Fcloudflared)                   |
| [GitHub Container Registry](https://github.com/peakimages/cloudflared/pkgs/container/cloudflared) | ![ghcr.io/peakimages/cloudflared](https://img.shields.io/github/v/release/peakimages/cloudflared?label=ghcr.io%2Fpeakimages%2Fcloudflared) |

## Configuration

cloudflared reads its settings from environment variables, override them with `-e` or the `environment` section of a docker compose service. Every flag of `cloudflared tunnel run` has one, see the [run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/cloudflared-parameters/run-parameters/).

| Variable         | Default           | Meaning                                                                                                                                                                            |
| ---------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TUNNEL_TOKEN`   | unset             | Token of the tunnel from the Cloudflare dashboard. Set it here rather than with `--token`, which puts it on the command line of the process                                        |
| `TUNNEL_METRICS` | `127.0.0.1:20241` | Address of the metrics port. `0.0.0.0:20241` opens it to Prometheus, a Kubernetes HTTP probe and `cloudflared tunnel diag` on the host, and to every container on the same network |

## Attestations

Every image carries an SBOM and a provenance attestation.

The SBOM lists the packages of the image, cloudflared, its Go modules and the CA bundle:

```sh
docker buildx imagetools inspect peakimages/cloudflared:latest --format '{{ json .SBOM }}'
```

The provenance records how the image was built:

```sh
docker buildx imagetools inspect peakimages/cloudflared:latest --format '{{ json .Provenance }}'
```

A scanner lists the same packages, Trivy names cloudflared by its Go module alone:

```sh
syft peakimages/cloudflared:latest
grype peakimages/cloudflared:latest
trivy image peakimages/cloudflared:latest
```

## Releases

Every cloudflared release becomes a new version of the image. A check for new cloudflared releases runs twice a day.

The image version follows semantic versioning independently of cloudflared. Changes to the image are listed in [CHANGELOG.md](CHANGELOG.md).
