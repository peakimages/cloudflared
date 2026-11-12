#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
IMAGE="${1:-}"
CONTAINER=cloudflared-test

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap cleanup EXIT

main() {
	[[ "$OPTION" =~ ^[^-][^[:space:]]*$ ]] || die "'$OPTION' is not an option, expected an image"
	heading "Testing $IMAGE"
	read_platform
	check_version
	check_default_command
	heading "Tunnel"
	start_tunnel
	check_request
	check_private_metrics
	check_stop
	heading "All tests passed for $IMAGE"
}

read_platform() {
	platform="$(docker image inspect -f '{{.Os}}/{{.Architecture}}{{with .Variant}}/{{.}}{{end}}' "$IMAGE" 2> /dev/null)" || die "$IMAGE is not a local image, build it first"
	ok "$IMAGE is built for $platform"
}

check_version() {
	local version printed
	printed="$(docker run --rm --platform "$platform" "$IMAGE" version)"
	version="${printed#cloudflared version }"
	version="${version%% *}"
	jq -e --arg version "$version" 'any(.cloudflared[]; .version == $version)' src/upstream.json > /dev/null || die "cloudflared version prints '$printed', expected a version src/upstream.json pins"
	if [[ "$printed" == *" with FIPS)" ]]; then
		ok "cloudflared version prints $version, a version src/upstream.json pins, as a FIPS build"
	else
		ok "cloudflared version prints $version, a version src/upstream.json pins"
	fi
}

check_default_command() {
	local printed
	printed="$(docker run --rm --platform "$platform" -e TUNNEL_TOKEN=invalid "$IMAGE" 2>&1)" && die "the image ran without a command and with an invalid TUNNEL_TOKEN, expected cloudflared tunnel run to reject the token"
	[[ "$printed" == "Provided Tunnel token is not valid."* ]] || die "the image prints '$printed' without a command, expected cloudflared tunnel run to reject TUNNEL_TOKEN"
	ok "the image runs cloudflared tunnel run by default and reads the token from TUNNEL_TOKEN"
}

start_tunnel() {
	docker network create "$CONTAINER" > /dev/null
	docker run -d --name "$CONTAINER" --platform "$platform" --network "$CONTAINER" --read-only --cap-drop ALL --security-opt no-new-privileges \
		--health-interval 2s --health-start-period 1s "$IMAGE" tunnel --hello-world > /dev/null
	wait_healthy "$CONTAINER"
	ok "a quick tunnel connects and passes the health check with a read-only root filesystem and all capabilities dropped"
}

check_request() {
	local url page=""
	url="$(docker logs "$CONTAINER" 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | head -n 1)"
	[ -n "$url" ] || die "cloudflared logs no trycloudflare.com address for the quick tunnel"
	for _ in $(seq 30); do
		page="$(fetch "" "$url" 2> /dev/null)" && break
		sleep 2
	done
	[[ "$page" == *"Congrats! You created a tunnel!"* ]] || die "$url does not answer with the page of the hello world server"
	ok "a request from the internet reaches the hello world server through the tunnel"
}

check_private_metrics() {
	fetch "container:$CONTAINER" http://127.0.0.1:20241/ready > /dev/null \
		|| die "the metrics port does not answer /ready on 127.0.0.1:20241 inside the container"
	fetch "$CONTAINER" "http://$CONTAINER:20241/ready" > /dev/null 2>&1 \
		&& die "the metrics port answers other containers on the network, expected 127.0.0.1 only"
	ok "the metrics port answers on 127.0.0.1 inside the container and refuses other containers on the network"
}

check_stop() {
	local code
	SECONDS=0
	docker stop -t 10 "$CONTAINER" > /dev/null
	code="$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER")"
	[ "$code" = 0 ] || die "cloudflared exited with $code on docker stop, expected 0"
	[ "$SECONDS" -lt 10 ] || die "docker stop took $SECONDS seconds, expected cloudflared to end on SIGTERM"
	ok "docker stop ends cloudflared on SIGTERM in under 10 seconds with exit code 0"
}

wait_healthy() {
	for _ in $(seq 60); do
		[ "$(docker inspect -f '{{.State.Health.Status}}' "$1")" = healthy ] && return
		sleep 1
	done
	die "$1 did not become healthy: $(docker logs "$1" 2>&1 | tail -n 3)"
}

fetch() {
	docker run --rm ${1:+--network "$1"} "$(sed -n 's/^ARG BASE_IMAGE=//p' src/Dockerfile)" wget -q -T 10 -O - "$2"
}

cleanup() {
	docker rm -f "$CONTAINER" > /dev/null 2>&1 || true
	docker network rm "$CONTAINER" > /dev/null 2>&1 || true
}

main
