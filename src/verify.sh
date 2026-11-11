#!/bin/sh
set -eu

die() {
	echo "verify: $*" >&2
	exit 1
}

cd "$(dirname "$0")"

main() {
	check_commit
	echo "verify: cloudflared $CLOUDFLARED_VERSION, the tag points to commit $commit"
}

check_commit() {
	commit="$(git -C source rev-parse HEAD)"
	[ "$commit" = "$(pin commit)" ] || die "tag $CLOUDFLARED_VERSION points to $commit, expected $(pin commit)"
}

pin() {
	jq -r ".$1" cloudflared.json
}

main
