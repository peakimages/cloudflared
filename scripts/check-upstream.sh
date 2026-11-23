#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
REPOSITORY=cloudflare/cloudflared
BUILD_FILES="Makefile,check-fips.sh,.ci/scripts/linux/build-packages.sh,.ci/scripts/linux/build-packages-fips.sh"
DIFF_FILE="${DIFF_FILE:-/dev/null}"
BODY_FILE="${BODY_FILE:-/dev/null}"
VERSION_FILE=release.json
PATCH_FILE=src/patches/dependencies.patch
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
	list_dropped_dependencies
	write_upstream_json
	update_dockerfile
	link_release_notes
	write_notes
	update_changelog
}

read_newest_release() {
	version="$(gh api "repos/$REPOSITORY/releases/latest" --jq .tag_name)"
	[[ "$version" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+$ ]] || die "the latest release of $REPOSITORY is '$version', expected year.month.patch"
	releases="$(gh api "repos/$REPOSITORY/releases?per_page=100" --jq '.[] | select((.draft or .prerelease) | not) | .tag_name' \
		| sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+)$/\1/p')"
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

list_dropped_dependencies() {
	local module raised required modules=()
	dropped=
	[ -f "$PATCH_FILE" ] || return 0
	fetch "$version" go.mod > "$WORK_DIR/go.mod"
	while IFS=@ read -r module raised; do
		required="$(awk -v module="$module" '/^require \($/ { block = 1; next } /^\)/ { block = 0 } (block || sub(/^require /, "")) && $1 == module { print $2 }' "$WORK_DIR/go.mod")"
		[ -n "$required" ] && [ "$(printf '%s\n' "$required" "$raised" | sort -V | head -n 1)" != "$raised" ] || modules+=("\`$module\`")
	done < <(awk '/^diff --git/ { exit } NF == 2 { print $2 }' "$PATCH_FILE")
	[ "${#modules[@]}" -gt 0 ] || return 0
	printf -v dropped '%s, ' "${modules[@]}"
	dropped="${dropped%, }"
	[ "${#modules[@]}" -eq 1 ] || dropped="${dropped%, *} and ${dropped##*, }"
	info "the patch drops $dropped, cloudflared $version requires the fixed version"
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

link_release_notes() {
	local skipped release
	skipped="$(printf '%s\n' "$releases" "$pinned" "$version" | sort -Vu | awk -v from="$pinned" -v to="$version" '$0 == to { done = 1 } on && !done; $0 == from { on = 1 }')"
	if [ -z "$skipped" ]; then
		notes="its [release notes]($(notes_url "$version"))"
		return
	fi
	notes="the release notes of "
	for release in $skipped; do
		notes+="[v$release]($(notes_url "$release")), "
	done
	notes="${notes%, } and [v$version]($(notes_url "$version"))"
}

write_notes() {
	{
		printf -- '### Changed\n\n- cloudflared from v%s to v%s, see %s\n' "$pinned" "$version" "$notes"
		[ -z "$dropped" ] || printf '  - The patch for %s is no longer needed, as cloudflared v%s already requires the fixed versions\n' "$dropped" "$version"
	} > "$WORK_DIR/notes.md"
	{
		printf -- '## Changes\n\n- Bump cloudflared version from v%s to v%s, see %s\n' "$pinned" "$version" "$notes"
		[ -z "$dropped" ] || printf -- '- Drop %s from the dependency patch, as cloudflared v%s already requires the fixed versions\n' "$dropped" "$version"
	} > "$BODY_FILE"
}

update_changelog() {
	local branch tag
	branch="$(git branch --show-current)"
	if [[ "$branch" =~ ^(next|release/v[0-9]+\.[0-9]+)$ ]]; then
		info "$branch publishes prereleases only, the next one ships cloudflared $version"
		return
	fi
	tag="v$version-v$(jq -r .stable.image "$VERSION_FILE")"
	awk -v heading="## [$tag] - $(date +%Y-%m-%d)" -v notes="$WORK_DIR/notes.md" '
		/^## \[v/ && !added {
			print heading "\n"
			while ((getline line < notes) > 0) print line
			print ""
			added = 1
		}
		1
	' CHANGELOG.md > "$WORK_DIR/CHANGELOG.md"
	cp "$WORK_DIR/CHANGELOG.md" CHANGELOG.md
	ok "CHANGELOG.md lists cloudflared $version under $BOLD## [$tag]$RESET"
}

notes_url() { echo "https://github.com/$REPOSITORY/blob/refs/tags/$1/RELEASE_NOTES"; }

fetch() {
	curl --proto '=https' --tlsv1.2 -sSf --retry 3 "https://raw.githubusercontent.com/$REPOSITORY/refs/tags/$1/$2"
}

main
