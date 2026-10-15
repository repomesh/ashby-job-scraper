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
  (`restrict,command=...` in `~/.ssh/authorized_keys`). It pulls the new tag before recording it in
  `.env`, keeps only the new and previous image tags, and rolls back unless the new image is the one running,
  reports healthy and answers `https://jobs.whatrunsindia.com/api/health` (which runs `SELECT 1`) through Cloudflare.
  After a rollback it waits for the previous image the same way and says whether that worked.

`deploy.sh` and `docker-compose.yml` are copied to the server by hand when they change: the deploy key
can only run `deploy.sh`, so it can't update either file (on purpose). Ship the image first when a change
depends on new app code (like a healthcheck route), then copy the files and run `docker compose up -d`.

Cloudflare (zone whatrunsindia.com, host `jobs`): a proxied CNAME to `<tunnel-id>.cfargotunnel.com`, the tunnel's
ingress `jobs.whatrunsindia.com -> http://web:3000`, Cache Rules for the public pages and `/api/jobs` (they honour
the app's `Cache-Control`), and a custom firewall rule blocking AI/SEO crawlers on `/jobs/`.

Trust boundaries (checked on the server 2026-10-15): nothing listens on a host port (`web` exposes 3000 only on
the compose network), so the tunnel is the only way in, and its ingress routes nothing but `jobs` (everything else
gets 404). That is why the app may trust `cf-connecting-ip` (lib/rate-limit.ts) and why `AUTH_URL` pins the sign-in
host to `https://jobs.whatrunsindia.com` whatever `Host` a request claims. The deploy key's `authorized_keys` line is
`restrict,command="…/deploy.sh"`, so it can't open a shell, forward ports or run anything else.

Deploys: `.github/workflows/deploy-web.yml` on every push to `main`. By hand: `ssh <key> ubuntu@<server> <image-tag>`
with a token that can read the GHCR package on stdin.
