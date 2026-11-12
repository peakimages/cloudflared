#!/bin/sh
set -eu

die() {
	echo "rootfs: $*" >&2
	exit 1
}

main() {
	install_cloudflared
	install_ca_bundle
	create_user
	create_directories
	echo "rootfs: cloudflared $CLOUDFLARED_VERSION and the CA bundle installed"
}

install_cloudflared() {
	install -D -m 0755 /src/cloudflared /rootfs/usr/local/bin/cloudflared
	reported="$(/rootfs/usr/local/bin/cloudflared --version)"
	case "$reported" in
		"cloudflared version $CLOUDFLARED_VERSION "*) ;;
		*) die "cloudflared reports $reported, expected cloudflared version $CLOUDFLARED_VERSION" ;;
	esac
	[ "${FLAVOR:-}" != fips ] || echo "$reported" | grep -q ' with FIPS)$' || die "cloudflared reports $reported, expected a FIPS build"
}

install_ca_bundle() {
	install -D -m 0644 /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/ca-certificates.crt
}

create_user() {
	install -d /rootfs/etc
	echo "nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin" > /rootfs/etc/passwd
	echo "nonroot:x:65532:" > /rootfs/etc/group
}

create_directories() {
	install -d -m 0700 -o 65532 -g 65532 /rootfs/home/nonroot
	install -d -m 1777 /rootfs/tmp
}

main
