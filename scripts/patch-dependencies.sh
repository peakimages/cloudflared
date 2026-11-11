#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
LOCKFILES="go.mod"
PATCH_FILE=src/patches/dependencies.patch
COREPACK=corepack@0.36.0
WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' BLUE=$'\033[34m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RED=$'\033[31m' RESET=$'\033[0m'

info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$YELLOW" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap 'rm -rf "$WORK_DIR"' EXIT

main() {
	[[ "$OPTION" =~ ^(--check|--remove([[:space:]][^-][^[:space:]]*)*|[^-][^[:space:]]*@[^[:space:]@]+([[:space:]][^-][^[:space:]]*@[^[:space:]@]+)*)?$ ]] \
		|| die "'$OPTION' is not an option, expected name@version such as github.com/go-chi/chi/v5@v5.4.0, --remove with names, --check or none"
	list_dependencies "$@"
	clone_pinned_release
	[ "$OPTION" != --check ] || check_patch
	raise_dependencies
	write_patch
}

list_dependencies() {
	local name
	{ [ ! -f "$PATCH_FILE" ] || awk '/^diff --git/ { exit } NF == 2 { print $2 }' "$PATCH_FILE"; } | merge_versions > "$WORK_DIR/listed"
	if [ "${1:-}" = --check ]; then
		cp "$WORK_DIR/listed" "$WORK_DIR/dependencies"
	elif [ "${1:-}" = --remove ]; then
		shift
		for name in "$@"; do
			awk -v name="$name" '{ sub(/@[^@]*$/, "") } $0 == name { found = 1 } END { exit !found }' "$WORK_DIR/listed" || die "$PATCH_FILE does not raise $name, expected one of the dependencies it lists"
		done
		[ "$#" -gt 0 ] || : > "$WORK_DIR/listed"
		awk -v remove=" $* " '{ name = $0; sub(/@[^@]*$/, "", name) } index(remove, " " name " ") == 0' "$WORK_DIR/listed" > "$WORK_DIR/dependencies"
	else
		printf '%s\n' "$@" | cat "$WORK_DIR/listed" - | merge_versions > "$WORK_DIR/dependencies"
	fi
}

clone_pinned_release() {
	local lockfile
	project="$(basename "$(pin repository)")" version="$(pin version)"
	git -c advice.detachedHead=false clone --quiet --depth 1 --revision="$(pin commit)" "$(pin repository).git" "$WORK_DIR/source"
	for lockfile in $LOCKFILES; do
		[ -f "$WORK_DIR/source/$lockfile" ] || die "$project $version has no $lockfile, expected every lockfile LOCKFILES names"
	done
	info "cloned the commit of $project $BOLD$version$RESET that src/upstream.json pins, with its $LOCKFILES"
}

check_patch() {
	local lockfile dependency required removable=0
	if [ ! -f "$PATCH_FILE" ]; then
		ok "there is no $PATCH_FILE, $project $version is built with the dependencies it requires"
		exit 0
	fi
	while read -r lockfile dependency; do
		required="$(required_version "$lockfile" "${dependency%@*}")"
		if [ -z "$required" ] || at_least "$required" "${dependency##*@}"; then
			warn "$project $version requires ${dependency%@*} ${required:-no longer} in $lockfile, $PATCH_FILE no longer has to raise it"
			removable=$((removable + 1))
		else
			ok "$project $version requires ${dependency%@*} $required in $lockfile, $PATCH_FILE raises it to $BOLD${dependency##*@}$RESET"
		fi
	done < <(awk '/^diff --git/ { exit } NF == 2 { print }' "$PATCH_FILE")
	[ "$removable" = 0 ] || die "$PATCH_FILE has $removable raise(s) that $project $version no longer needs, run scripts/patch-dependencies.sh to drop them"
	git -C "$WORK_DIR/source" apply --check "$PWD/$PATCH_FILE" 2> /dev/null || die "$PATCH_FILE does not apply to $project $version, run scripts/patch-dependencies.sh to write it again"
	ok "$PATCH_FILE applies to $project $version"
	exit 0
}

raise_dependencies() {
	local lockfile dependency required raising found=" "
	raised=()
	for lockfile in $LOCKFILES; do
		raising=()
		while read -r dependency; do
			required="$(required_version "$lockfile" "${dependency%@*}")"
			[ -n "$required" ] || continue
			found+="${dependency%@*} "
			if at_least "$required" "${dependency##*@}"; then
				info "$project $version requires ${dependency%@*} $required in $lockfile already, the patch leaves it out"
			else
				raising+=("$dependency")
			fi
		done < "$WORK_DIR/dependencies"
		[ "${#raising[@]}" -eq 0 ] || raise_in "$lockfile" "${raising[@]}"
	done
	while read -r dependency; do
		[[ "$found" == *" ${dependency%@*} "* ]] || info "$project $version does not require ${dependency%@*} in $LOCKFILES, the patch leaves it out"
	done < "$WORK_DIR/dependencies"
}

required_version() {
	local file="$WORK_DIR/source/$1"
	case "${1##*/}" in
		go.mod) awk -v module="$2" '/^[a-z]+ \($/ { block = $1 } /^\)/ { block = "" } { sub(/^require[[:space:]]+/, "") } (block == "" || block == "require") && $1 == module && $2 ~ /^v/ { print $2 }' "$file" ;;
		Cargo.lock) awk -v crate="\"$2\"" '$1 == "name" { found = $3 == crate } $1 == "version" && found { gsub(/"/, "", $3); print $3 }' "$file" ;;
		composer.lock) jq -r --arg name "$2" '(.packages + ."packages-dev")[] | select(.name == $name) | .version' "$file" ;;
		package-lock.json | npm-shrinkwrap.json) jq -r --arg name "$2" '.packages // {} | to_entries[] | select(.key | endswith("node_modules/" + $name)) | .value.version // empty' "$file" ;;
		pnpm-lock.yaml | aube-lock.yaml) awk -v prefix="$2@" '/^  [^ ]/ { key = $1; gsub(/["\047]/, "", key); sub(/:$/, "", key); sub(/^\//, "", key); if (index(key, prefix) == 1) { key = substr(key, length(prefix) + 1); sub(/\(.*/, "", key); print key } }' "$file" ;;
		yarn.lock) awk -v prefix="$2@" '/^[^ #]/ { line = $0; gsub(/"/, "", line); found = index(line, prefix) == 1 || index(line, ", " prefix) > 0 } /^  version/ && found { gsub(/[":]/, "", $2); print $2 }' "$file" ;;
		bun.lock) awk -v start="[\"$2@" '{ i = index($0, start) } i { found = substr($0, i + length(start)); sub(/".*/, "", found); print found }' "$file" ;;
		*) die "LOCKFILES names $1, expected go.mod, Cargo.lock, composer.lock, package-lock.json, npm-shrinkwrap.json, pnpm-lock.yaml, yarn.lock, bun.lock or aube-lock.yaml" ;;
	esac | sort -V | head -n 1
}

raise_in() {
	local lockfile="$1" dependency required
	shift
	info "updating $lockfile"
	case "${lockfile##*/}" in
		go.mod)
			run_in GO_IMAGE "$lockfile" go get "$@"
			run_in GO_IMAGE "$lockfile" go mod tidy
			;;
		Cargo.lock)
			for dependency in "$@"; do
				run_in RUST_IMAGE "$lockfile" cargo update --package "${dependency%@*}@$(required_version "$lockfile" "${dependency%@*}")" --precise "${dependency##*@}"
			done
			;;
		composer.lock) run_in COMPOSER_IMAGE "$lockfile" composer update "${@/@/:}" --no-install --no-scripts --no-plugins --ignore-platform-reqs --with-dependencies --minimal-changes ;;
		package-lock.json | npm-shrinkwrap.json)
			update_package_json "$lockfile" '["overrides"]' "$@"
			run_in NODE_IMAGE "$lockfile" npm install --package-lock-only --ignore-scripts --no-audit --no-fund
			;;
		pnpm-lock.yaml)
			if jq -e .pnpm.overrides "$WORK_DIR/source/$(dirname "$lockfile")/package.json" > /dev/null; then
				update_package_json "$lockfile" '["pnpm", "overrides"]' "$@"
			else
				update_package_json "$lockfile" '[]' "$@"
				run_in NODE_IMAGE "$lockfile" npx --yes "$COREPACK" pnpm config get --location project overrides --json
				run_in NODE_IMAGE "$lockfile" npx --yes "$COREPACK" pnpm config set --location project --json overrides "$(jq -cs --argjson raised "$(versions_json "$@")" '(.[0] // {}) + $raised' "$WORK_DIR/output")"
			fi
			run_in NODE_IMAGE "$lockfile" npx --yes "$COREPACK" pnpm install --lockfile-only --ignore-scripts --store-dir /home/.pnpm-store
			;;
		yarn.lock)
			update_package_json "$lockfile" '["resolutions"]' "$@"
			if grep -q '^__metadata:' "$WORK_DIR/source/$lockfile"; then
				run_in NODE_IMAGE "$lockfile" npx --yes "$COREPACK" yarn install --mode=update-lockfile
			else
				run_in NODE_IMAGE "$lockfile" npx --yes "$COREPACK" yarn install --ignore-scripts --non-interactive
			fi
			;;
		bun.lock)
			update_package_json "$lockfile" '["overrides"]' "$@"
			run_in BUN_IMAGE "$lockfile" bun install --lockfile-only --ignore-scripts
			;;
		aube-lock.yaml)
			update_package_json "$lockfile" '["overrides"]' "$@"
			run_in AUBE_IMAGE "$lockfile" aube install --lockfile-only --ignore-scripts
			;;
	esac
	for dependency in "$@"; do
		required="$(required_version "$lockfile" "${dependency%@*}")"
		at_least "$required" "${dependency##*@}" || die "$lockfile requires ${dependency%@*} $required after the update, expected ${dependency##*@}"
		raised+=("$lockfile $dependency")
	done
}

update_package_json() {
	local package_json indent path="$2"
	package_json="$WORK_DIR/source/$(dirname "$1")/package.json"
	indent="$(awk 'NR == 2 { sub(/[^[:space:]].*/, ""); print; exit }' "$package_json")"
	shift 2
	jq --tab --argjson path "$path" --argjson raised "$(versions_json "$@")" \
		'(if $path == [] then . else setpath($path; (getpath($path) // {}) + $raised) end) | reduce ("dependencies", "devDependencies", "optionalDependencies") as $field (.; if .[$field] then .[$field] |= with_entries(.value = ($raised[.key] // .value)) else . end)' \
		"$package_json" | awk -v indent="$indent" '{ gsub(/\t/, indent) } 1' > "$WORK_DIR/package.json"
	cat "$WORK_DIR/package.json" > "$package_json"
}

run_in() {
	local image
	image="$(dockerfile_arg "$1")"
	[ -n "$image" ] || die "src/Dockerfile has no ARG $1, expected the image that updates ${2##*/}"
	mkdir -p "$WORK_DIR/home"
	docker run --rm --user "$(id -u):$(id -g)" --entrypoint "" -v "$WORK_DIR/home:/home" -v "$WORK_DIR/source:/source" -w "/source/$(dirname "$2")" \
		-e HOME=/home -e GOPATH=/home/go -e GOFLAGS=-modcacherw -e CARGO_HOME=/home/.cargo -e COREPACK_ENABLE_DOWNLOAD_PROMPT=0 -e NODE_OPTIONS=--max-old-space-size=4096 \
		"$image" "${@:3}" < /dev/null > "$WORK_DIR/output" 2> "$WORK_DIR/errors" \
		|| die "$1 stops updating $2: $(cat "$WORK_DIR/output" "$WORK_DIR/errors" | tail -n 5)"
}

write_patch() {
	local entry dependency
	git -C "$WORK_DIR/source" add --all
	if git -C "$WORK_DIR/source" diff --cached --quiet; then
		rm -f "$PATCH_FILE"
		ok "$project $version is built with the dependencies it requires, there is no $PATCH_FILE"
		return
	fi
	mkdir -p "$(dirname "$PATCH_FILE")"
	{
		printf 'The dependencies scripts/patch-dependencies.sh raises in %s %s:\n' "$project" "$version"
		printf '%s\n' "${raised[@]}" ""
		git -C "$WORK_DIR/source" diff --cached --default-prefix --no-color
	} > "$PATCH_FILE"
	for entry in "${raised[@]}"; do
		dependency="${entry#* }"
		ok "$PATCH_FILE raises ${dependency%@*} to $BOLD${dependency##*@}$RESET in ${entry%% *}"
	done
}

merge_versions() { awk 'NF { name = $0; sub(/@[^@]*$/, "", name); if (!(name in version)) order[++n] = name; version[name] = substr($0, length(name) + 2) } END { for (i = 1; i <= n; i++) print order[i] "@" version[order[i]] }'; }

versions_json() { jq -cn '$ARGS.positional | map(capture("^(?<key>.+)@(?<value>[^@]+)$")) | from_entries' --args "$@"; }

at_least() { [ "$(printf '%s\n%s\n' "${1#v}" "${2#v}" | sort -V | head -n 1)" = "${2#v}" ]; }

dockerfile_arg() { sed -n "s/^ARG $1=//p" src/Dockerfile; }

pin() { jq -r ".cloudflared.latest.$1" src/upstream.json; }

main "$@"
