# syntax=docker/dockerfile:1

# Set by scripts/check-upstream.sh
ARG CLOUDFLARED_VERSION=2026.10.7

# Dependencies
# https://hub.docker.com/_/golang/tags?name=1.27.4-alpine3.24
ARG GO_IMAGE=golang:1.27.4-alpine3.24@sha256:0a5f7fe796599ff487605987432e7619ae45beeb2fba4c2ce0b907879932aebf
# https://go.dev/doc/security/fips140
ARG GO_FIPS140_MODULE=v1.0.0-c2097c7c
# https://hub.docker.com/_/alpine/tags?name=3.24.4
ARG BASE_IMAGE=alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/ca-certificates-bundle
ARG CA_CERTIFICATES_VERSION=20261020-r0
# https://github.com/anchore/syft/tree/v1.57.1/schema/json
ARG SYFT_SCHEMA_VERSION=16.1.13

# Set by the build workflow
ARG VARIANT
ARG IMAGE_VERSION
ARG SOURCE_DATE_EPOCH
ARG CREATED
ARG GIT_SHA

FROM --platform=${BUILDPLATFORM} ${GO_IMAGE} AS compile

ARG CLOUDFLARED_VERSION
ARG GO_FIPS140_MODULE
ARG VARIANT
ARG TARGETARCH
ARG TARGETVARIANT

# git and jq are only used during the build stage, so they are not pinned to a specific version
# hadolint ignore=DL3018
RUN apk add --no-cache git jq

WORKDIR /src
COPY --chmod=0644 upstream.json verify.sh ./
RUN jq --arg version "$CLOUDFLARED_VERSION" '.cloudflared[] | select(.version == $version)' upstream.json > cloudflared.json \
    && git -c advice.detachedHead=false -c transfer.fsckObjects=true clone --quiet --depth 1 \
        --revision="refs/tags/${CLOUDFLARED_VERSION}" "$(jq -r .repository cloudflared.json).git" source \
    && sh verify.sh

# Go modules raised for a known vulnerability, see PATCHES.md
COPY --chmod=0644 patche[s]/dependencies.patch ./
RUN if [ -f dependencies.patch ]; then git -C source apply --verbose /src/dependencies.patch; fi

ENV CGO_ENABLED=0 \
    GOFLAGS="-mod=readonly -trimpath"

WORKDIR /src/source
RUN go mod download \
    && go mod verify

# The go build of the Makefile without symbol table and DWARF:
# https://github.com/cloudflare/cloudflared/blob/master/Makefile
RUN build_type="" fips140=off \
    && if [ "${VARIANT}" = fips ]; then build_type=FIPS fips140="${GO_FIPS140_MODULE}"; fi \
    && build_time="$(TZ=UTC git log -1 --format=%cd --date=format-local:'%Y-%m-%d-%H:%M UTC')" \
    && GOARCH="${TARGETARCH}" GOARM="${TARGETVARIANT#v}" GOFIPS140="${fips140}" go build -o /src/cloudflared \
        -ldflags="-s -w -X 'main.Version=${CLOUDFLARED_VERSION}' -X 'main.BuildTime=${build_time}' -X 'main.BuildType=${build_type}'" \
        ./cmd/cloudflared

FROM ${BASE_IMAGE} AS build

ARG CLOUDFLARED_VERSION
ARG CA_CERTIFICATES_VERSION
ARG SYFT_SCHEMA_VERSION
ARG VARIANT
ARG IMAGE_VERSION

# jq is only used during the build stage, so it is not pinned to a specific version
# hadolint ignore=DL3018
RUN apk add --no-cache jq ca-certificates-bundle=${CA_CERTIFICATES_VERSION}

WORKDIR /src
COPY --from=compile /src/cloudflared /src/cloudflared.json /src/
COPY --chmod=0644 rootfs.sh /src/
RUN sh /src/rootfs.sh

# A scratch image has no package database for the SBOM scanner to read, this syft JSON document takes its place
COPY --chmod=0644 sbom.sh /src/
RUN sh /src/sbom.sh "peakimages/cloudflared:${CLOUDFLARED_VERSION}${VARIANT:+-}${VARIANT}-v${IMAGE_VERSION:?}" \
        "generic|cloudflared|${CLOUDFLARED_VERSION}|Apache-2.0|$(jq -r .repository cloudflared.json)/archive/$(jq -r .commit cloudflared.json).tar.gz|cloudflare:cloudflared" \
        "apk|ca-certificates-bundle|alpinelinux:ca-certificates|/etc/ssl/certs/ca-certificates.crt"

FROM scratch AS final

ARG CLOUDFLARED_VERSION
ARG CA_CERTIFICATES_VERSION
ARG VARIANT
ARG IMAGE_VERSION
ARG CREATED
ARG GIT_SHA

COPY --from=build /rootfs/ /

LABEL org.opencontainers.image.title="cloudflared" \
    org.opencontainers.image.description="Minimal, hardened cloudflared Docker image built from the tagged source." \
    org.opencontainers.image.version="${CLOUDFLARED_VERSION}${VARIANT:+-}${VARIANT}-v${IMAGE_VERSION}" \
    org.opencontainers.image.created="${CREATED}" \
    org.opencontainers.image.revision="${GIT_SHA}" \
    org.opencontainers.image.licenses="Apache-2.0 AND MPL-2.0 AND MIT" \
    org.opencontainers.image.authors="PeakImages" \
    org.opencontainers.image.vendor="PeakImages" \
    org.opencontainers.image.url="https://hub.docker.com/r/peakimages/cloudflared" \
    org.opencontainers.image.source="https://github.com/peakimages/cloudflared" \
    org.opencontainers.image.documentation="https://github.com/peakimages/cloudflared#readme" \
    org.opencontainers.image.base.name="scratch" \
    dev.peakimages.cloudflared.version="${CLOUDFLARED_VERSION}" \
    dev.peakimages.cloudflared.variant="${VARIANT:-default}" \
    dev.peakimages.ca-certificates.version="${CA_CERTIFICATES_VERSION}" \
    dev.peakimages.image.version="${IMAGE_VERSION}"

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TUNNEL_METRICS=127.0.0.1:20241

WORKDIR /home/nonroot
USER 65532:65532

ENTRYPOINT ["/usr/local/bin/cloudflared", "--no-autoupdate"]
CMD ["tunnel", "run"]

HEALTHCHECK --interval=20s --timeout=5s --retries=3 \
    CMD ["/usr/local/bin/cloudflared", "tunnel", "ready"]
