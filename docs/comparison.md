# Comparison with other cloudflared images

`peakimages/cloudflared` compared to other popular cloudflared Docker images.

|                                    | `peakimages/cloudflared`                                       | `cloudflare/cloudflared`                          | `dhi.io/cloudflared`                               | `erisamoe/cloudflared`                                     |
| ---------------------------------- | -------------------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------- | ---------------------------------------------------------- |
| Base                               | scratch                                                        | Debian 13, distroless                             | Docker Hardened Debian 13                          | scratch                                                    |
| Rootless                           | ✅                                                             | ✅                                                | ✅                                                 | ❌                                                         |
| User                               | 65532 (nonroot)                                                | 65532 (nonroot)                                   | 65532 (nonroot)                                    | root                                                       |
| Binary protected from the user[^1] | ✅ (owned by root)                                             | ❌ (owned by the user)                            | ✅ (owned by root)                                 | ❌ (runs as root)                                          |
| Writable home[^2]                  | ✅ (`/home/nonroot`, owned by the user)                        | ✅ (`/home/nonroot`, owned by the user)           | ✅ (`/home/nonroot`, owned by the user)            | ⚠️ (`/`, as root)                                          |
| Open source                        | ✅ (`AGPL-3.0`)                                                | ✅ (`Apache-2.0`)                                 | ⚠️ (`Apache-2.0`, definitions only)                | ✅ (public domain)                                         |
| Verified source                    | ✅ (pinned commit, `go mod verify`)                            | ✅ (own repository)                               | ✅ (pinned commit)                                 | ❌ (unchecked clone)                                       |
| Reproducible build[^3]             | ✅                                                             | ❌                                                | unknown                                            | ❌                                                         |
| Stripped[^4]                       | ✅                                                             | ❌                                                | ⚠️ (DWARF only, symbol table kept)                 | ✅                                                         |
| Build[^5]                          | static                                                         | static                                            | static                                             | static                                                     |
| PIE[^6]                            | ❌                                                             | ❌                                                | ❌                                                 | ❌                                                         |
| Native health check                | ✅                                                             | ❌                                                | ❌                                                 | ❌                                                         |
| Private metrics port[^7]           | ✅ (`127.0.0.1:20241`)                                         | ❌ (all interfaces)                               | ❌ (all interfaces)                                | ❌ (all interfaces)                                        |
| FIPS 140-3 flavor[^8]              | ✅ (`fips`, free, validated Go module)                         | ❌                                                | ⚠️ (paid subscription)                             | ❌                                                         |
| No shell                           | ✅                                                             | ✅                                                | ✅                                                 | ✅                                                         |
| No package manager                 | ✅                                                             | ✅                                                | ✅                                                 | ✅                                                         |
| Packages[^9]                       | ✅ (CA bundle only)                                            | ❌ (10 Debian packages, glibc and OpenSSL unused) | ⚠️ (4 Debian packages, cloudflared as one of them) | ⚠️ (CA bundle, not declared)                               |
| Compressed[^10]                    | 8.38 MB                                                        | 28.49 MB                                          | 9.28 MB                                            | 9.43 MB                                                    |
| On disk[^10]                       | 25.93 MB                                                       | 76.91 MB                                          | 32.57 MB                                           | 26.10 MB                                                   |
| Platforms                          | amd64, arm64, arm/v7, arm/v6, 386, riscv64, ppc64le, s390x     | amd64, arm64                                      | amd64, arm64                                       | amd64, arm64, arm/v7, arm/v6, 386, riscv64, ppc64le, s390x |
| cloudflared                        | 2026.11.0                                                      | 2026.11.0                                         | 2026.10.7                                          | 2026.10.0                                                  |
| Go                                 | 1.27.4                                                         | 1.27.4                                            | 1.27.4                                             | 1.26.10                                                    |
| cloudflared updates                | ⚠️ (checked twice a day, merged by hand)                       | ✅ (10 minutes after the release)                 | ✅ (15 hours after the release)                    | ❌ (by hand, 8 releases behind)                            |
| Patched base dependencies          | ✅ (Go, Alpine and the CA bundle pinned)                       | ❌ (only with a cloudflared release)              | ✅ (by Docker's patch SLA)                         | ⚠️ (by hand, Go 1.26.10)                                   |
| Patched project dependencies       | ✅ (`golang.org/x/net` v0.62.0, `golang.org/x/crypto` v0.59.0) | ❌ (only with a cloudflared release)              | ✅ (`golang.org/x/net` v0.62.0)                    | ❌                                                         |
| Known vulnerabilities[^11]         | 0                                                              | 3 high, 16 medium, 8 low, 9 unknown               | 1 unknown                                          | 4 high, 10 medium, 2 unknown                               |
| Maintained                         | ✅                                                             | ✅                                                | ✅                                                 | ⚠️ (last update 2026-10-20)                                |
| OCI labels                         | ✅                                                             | ⚠️ (`source` only)                                | ⚠️ (annotations only)                              | ❌                                                         |

[^1]: A process that owns the program it runs can replace it, and the next start of the container runs the replacement.

[^2]: `cloudflared tunnel login` and `tunnel create` write the account certificate and the tunnel credentials to `~/.cloudflared`.

[^3]: Building the same commit again gives the same image byte for byte, so a rebuild shows whether a published image really comes from its source. The image manifest of each platform keeps its digest, while the digest of a tag changes with every build because the provenance attestation records the build run.

[^4]: The symbol table and the DWARF debug information are only read by debuggers and profilers, and are 12 MB of the 37.6 MB official binary.

[^5]: A static binary carries its own libraries and needs nothing from the OS, so cloudflared never loads `libc6`, `libssl3t64` or `zlib1g` of the official image.

[^6]: A position-independent executable is loaded at a random memory address on every start, so an exploit cannot rely on known memory addresses. Go links a static binary as a PIE only with cgo and a C toolchain for every platform.

[^7]: The metrics port also serves profiles on `/debug/pprof`, the ingress rules on `/config` and diagnostics on `/diag`, and on all interfaces every container on the same network can read them.

[^8]: Only a validated module counts for FIPS 140-3. The `fips` flavor is built with the Go Cryptographic Module v1.0.0, CMVP certificate 5247, https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/5247, and is the only FIPS image of cloudflared that is free. Cloudflare publishes no FIPS image, its FIPS packages are built with `GOFIPS140=latest`, the module of the Go toolchain, which is not validated.

[^9]: cloudflared needs the CA bundle and nothing else, it logs in UTC and reads no time zone data, so every other package is more to patch and to scan.

[^10]: Measured for `linux/arm64` on 2026-11-12.

[^11]: Trivy 0.76.1 with `--scanners vuln` and its database of 2026-11-12.
