---
type: security
---
Patched two Go modules of cloudflared with known vulnerabilities

- `golang.org/x/net` from v0.61.0 to v0.62.0 for [CVE-2026-78661](https://www.cve.org/CVERecord?id=CVE-2026-78661) and [CVE-2026-97045](https://www.cve.org/CVERecord?id=CVE-2026-97045)
- `golang.org/x/crypto` from v0.58.0 to v0.59.0 for [GO-2026-5932](https://pkg.go.dev/vuln/GO-2026-5932)
