# Web app on the Oracle server

The server (Oracle Always Free ARM, shared with another project) runs two containers from `docker-compose.yml`
in `~/ashby-web`: `web` (the Next.js standalone image from `web/Dockerfile`) and `cloudflared` (the tunnel
connector). No ports are published; Cloudflare reaches `web:3000` through the tunnel.

Files on the server (not in git):

- `.env` (mode 600): `TUNNEL_TOKEN` (the remotely-managed tunnel `ashby-web`) and `WEB_TAG` (the image tag
  `deploy.sh` last started).
- `web.env` (mode 600): the app's settings: `DATABASE_URL`, `DB_POOL_MAX`, `AUTH_SECRET`, `AUTH_URL`,
  `AUTH_TRUST_HOST`, `AUTH_GOOGLE_ID/SECRET`, `AUTH_GITHUB_ID/SECRET`, `EMAIL_*`. Changing it needs
  `docker compose up -d --force-recreate web`.
- `deploy.sh`: copied from this folder. It is the only command the GitHub Actions deploy key may run
  (`restrict,command=...` in `~/.ssh/authorized_keys`).

Cloudflare (zone whatrunsindia.com, host `jobs`): a proxied CNAME to `<tunnel-id>.cfargotunnel.com`, the tunnel's
ingress `jobs.whatrunsindia.com -> http://web:3000`, Cache Rules for the public pages and `/api/jobs` (they honour
the app's `Cache-Control`), and a custom firewall rule blocking AI/SEO crawlers on `/jobs/`.

Deploys: `.github/workflows/deploy-web.yml` on every push to `main`. By hand: `ssh <key> ubuntu@<server> <image-tag>`
with a token that can read the GHCR package on stdin.
