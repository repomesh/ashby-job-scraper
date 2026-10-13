# syntax=docker/dockerfile:1
# The web app (web/) as a Next.js standalone server. Build from the repo root, because web/ imports ../src:
#   DATABASE_URL=... docker build -f web/Dockerfile --secret id=database_url,env=DATABASE_URL .
# The build prerenders pages from the live database (a BuildKit secret, never stored in the image).

FROM node:22-bookworm-slim AS build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /repo
ENV NEXT_TELEMETRY_DISABLED=1

# web/ imports ../src, which needs the root package's dependencies (sanitize-html, cities.json).
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

COPY web/package.json web/package-lock.json ./web/
RUN cd web && npm ci --legacy-peer-deps --ignore-scripts

COPY src ./src
COPY web ./web

ARG NEXT_PUBLIC_SITE_URL=https://jobs.whatrunsindia.com
# DOCKER_BUILD turns on the standalone output (next.config.ts); REQUIRE_DB makes the data
# lookups throw instead of falling back to empty (lib/query.ts), so a build that can't read the
# database fails instead of prerendering an empty site.
ENV DOCKER_BUILD=1 REQUIRE_DB=1 NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
WORKDIR /repo/web
# Two outside things fail a build now and then: prerender queries hit "too many clients" when the
# 50-connection database happens to be full, and the Google Fonts download times out. Retry for
# those two reasons only.
RUN --mount=type=secret,id=database_url,required=true \
    export DATABASE_URL="$(cat /run/secrets/database_url)"; \
    for attempt in 1 2 3; do \
      npm run build 2>&1 | tee /tmp/build.log && exit 0; \
      grep -q -e "too many clients" -e "next/font/google" /tmp/build.log || exit 1; \
      echo "Transient build failure (attempt $attempt), retrying in 45s"; sleep 45; \
    done; exit 1
# The path below is where tracing from the repo root puts the server; fail loudly if it moves.
RUN test -f .next/standalone/web/server.js || { echo "standalone layout changed:"; find .next/standalone -maxdepth 3 -name server.js; exit 1; }


FROM node:22-bookworm-slim AS run
LABEL org.opencontainers.image.source="https://github.com/rishilahoti/ashby-job-scraper"
# Changes with every build, so the security updates below are never served from a cached layer.
ARG CACHE_BUST=0
RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000 HOSTNAME=0.0.0.0
WORKDIR /repo
COPY --from=build --chown=node:node /repo/web/.next/standalone ./
COPY --from=build --chown=node:node /repo/web/.next/static ./web/.next/static
COPY --from=build --chown=node:node /repo/web/public ./web/public
USER node
EXPOSE 3000
CMD ["node", "web/server.js"]
