#!/usr/bin/env bash
# The ONLY command the GitHub Actions deploy key may run (authorized_keys "command=" on the server).
# The workflow sends the image tag as the ssh command and a short-lived GitHub token on stdin:
#   printf '%s\n' "$GITHUB_TOKEN" | ssh deploy-host "<tag>"
# Pulls that image, restarts the web container, and rolls back to the previous tag if the new one
# never becomes healthy.
set -euo pipefail
cd "$(dirname "$0")"

tag="${SSH_ORIGINAL_COMMAND:-}"
[[ "$tag" =~ ^[A-Za-z0-9._-]{1,100}$ ]] || { echo "refusing: bad image tag" >&2; exit 2; }
IFS= read -r token

printf '%s\n' "$token" | docker login ghcr.io -u rishilahoti --password-stdin >/dev/null
trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT

previous="$(grep -E '^WEB_TAG=' .env | cut -d= -f2- || true)"
set_tag() { grep -v '^WEB_TAG=' .env > .env.tmp || true; printf 'WEB_TAG=%s\n' "$1" >> .env.tmp; chmod 600 .env.tmp; mv .env.tmp .env; }

set_tag "$tag"
docker compose pull web
# Compose itself fails when the web container is unhealthy; the check below decides what to do.
docker compose up -d --remove-orphans || echo "compose up reported a problem, checking health" >&2

for _ in $(seq 1 30); do
  state="$(docker inspect --format '{{.State.Health.Status}}' ashby-web-web-1 2>/dev/null || echo none)"
  [ "$state" = healthy ] && { echo "deployed $tag"; docker image prune -f >/dev/null; exit 0; }
  sleep 5
done

echo "new image never became healthy; going back to '${previous:-none}'" >&2
docker compose logs --tail 40 web >&2 || true
if [ -n "$previous" ]; then set_tag "$previous"; docker compose up -d --remove-orphans; fi
exit 1
