#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
REPOSITORY=cloudflare/cloudflared
BUILD_FILES="Makefile,check-fips.sh,.ci/scripts/linux/build-packages.sh,.ci/scripts/linux/build-packages-fips.sh"
DIFF_FILE="${DIFF_FILE:-/dev/null}"
WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' BLUE=$'\033[34m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap 'rm -rf "$WORK_DIR"' EXIT

main() {
	[ -z "$OPTION" ] || die "'$OPTION' is not an option, expected none"
	read_newest_release
	compare_with_pinned
	compare_go_versions
	compare_build_files
	write_upstream_json
	update_dockerfile
}

read_newest_release() {
	version="$(gh api "repos/$REPOSITORY/releases/latest" --jq .tag_name)"
	[[ "$version" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+$ ]] || die "the latest release of $REPOSITORY is '$version', expected year.month.patch"
	commit="$(gh api "repos/$REPOSITORY/commits/refs/tags/$version" --jq .sha)"
}

compare_with_pinned() {
	pinned="$(jq -r '.cloudflared.latest.version' src/upstream.json)"
	if [ "$version" = "$pinned" ]; then
		ok "cloudflared $BOLD$pinned$RESET is pinned and the newest release on GitHub"
		exit 0
	fi
	info "GitHub lists cloudflared $BOLD$version$RESET, $pinned is pinned"
}

compare_go_versions() {
	local ours required
	ours="$(sed -nE 's/^ARG GO_IMAGE=golang:([0-9.]+)-.*/\1/p' src/Dockerfile)"
	required="$(fetch "$version" go.mod | sed -nE 's/^(go |toolchain go)([0-9.]+)$/\2/p' | sort -V | tail -n 1)"
	[ "$(printf '%s\n' "$ours" "$required" | sort -V | head -n 1)" = "$required" ] \
		|| die "cloudflared $version requires Go $required, src/Dockerfile builds with Go $ours"
	ok "src/Dockerfile builds with Go $BOLD$ours$RESET, cloudflared $version requires Go $required"
}

compare_build_files() {
	local file
	for file in ${BUILD_FILES//,/ }; do
		fetch "$pinned" "$file" > "$WORK_DIR/pinned"
		fetch "$version" "$file" > "$WORK_DIR/new"
		diff -u --label "$pinned/$file" --label "$version/$file" "$WORK_DIR/pinned" "$WORK_DIR/new" >> "$WORK_DIR/build.diff" || true
	done
	if [ ! -s "$WORK_DIR/build.diff" ]; then
		ok "the build files of cloudflared $version are the same as in $pinned"
		return
	fi
	info "the build files of cloudflared changed from $pinned to $BOLD$version$RESET, check the go build in src/Dockerfile against them"
	sed 's/^/    /' "$WORK_DIR/build.diff"
	cp "$WORK_DIR/build.diff" "$DIFF_FILE"
}

write_upstream_json() {
	jq --tab --arg version "$version" --arg repository "https://github.com/$REPOSITORY" --arg commit "$commit" \
		'.cloudflared.latest = {$version, $repository, $commit}' src/upstream.json > "$WORK_DIR/upstream.json"
	cp "$WORK_DIR/upstream.json" src/upstream.json
	ok "src/upstream.json pins $BOLD$version$RESET with commit ${commit:0:10}"
}

update_dockerfile() {
	sed -E "s|^ARG CLOUDFLARED_VERSION=.*|ARG CLOUDFLARED_VERSION=$version|" src/Dockerfile > "$WORK_DIR/Dockerfile"
	cp "$WORK_DIR/Dockerfile" src/Dockerfile
	ok "src/Dockerfile sets CLOUDFLARED_VERSION $BOLD$version$RESET"
}

fetch() {
	curl --proto '=https' --tlsv1.2 -sSf --retry 3 "https://raw.githubusercontent.com/$REPOSITORY/refs/tags/$1/$2"
}

main
