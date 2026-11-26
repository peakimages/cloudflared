---
type: security
---

Patched the two WebSocket modules of cloudflared with a known vulnerability

- `github.com/gobwas/ws` from v1.2.1 to v1.5.0 for [GO-2026-6940](https://pkg.go.dev/vuln/GO-2026-6940)
- `github.com/gorilla/websocket` from v1.5.3 to v1.5.4-0.20250319132907-e064f32e3674 for [GO-2026-6278](https://pkg.go.dev/vuln/GO-2026-6278)
