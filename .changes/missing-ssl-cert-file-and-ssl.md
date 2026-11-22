---
type: fixed
---

Missing `SSL_CERT_FILE` and `SSL_CERT_DIR` environment variables

- `SSL_CERT_FILE` points at the CA bundle of the image, `/etc/ssl/certs/ca-certificates.crt`, as in the official image, and lets users set another bundle at runtime
- `SSL_CERT_DIR` points at `/etc/ssl/certs`, the directory Go reads by default, and lets users set other directories at runtime
