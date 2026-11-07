
# syntax=docker/dockerfile:1.7

# ==========================================
# Stage 1 - Build Jellyfin Server
# ==========================================
FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS server-build

WORKDIR /src/server
COPY src/server/ ./

RUN --mount=type=cache,id=jellyfin-nuget,target=/root/.nuget/packages,sharing=locked \
    dotnet restore Jellyfin.sln --disable-parallel

RUN --mount=type=cache,id=jellyfin-nuget,target=/root/.nuget/packages,sharing=locked \
    dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
    -c Release \
    --no-restore \
    -o /out/server

RUN test -f /out/server/jellyfin.dll

# ==========================================
# Stage 2 - Build Jellyfin Web
# ==========================================
FROM node:20-bookworm AS web-build

WORKDIR /src/web

COPY src/web/package.json src/web/package-lock.json ./

RUN --mount=type=cache,id=jellyfin-npm,target=/root/.npm,sharing=locked \
    npm ci --include=dev --prefer-offline --no-audit --no-fund

COPY src/web/ ./
COPY ci/webpack.ci.js ./webpack.ci.js

ENV NODE_ENV=production
ENV WEBPACK_CACHE_DIR=/src/web/.webpack-cache

RUN --mount=type=cache,id=jellyfin-webpack,target=/src/web/.webpack-cache,sharing=locked \
    ./node_modules/.bin/webpack --config webpack.ci.js \
    && test -f dist/index.html

# ==========================================
# Stage 3 - Jellyfin Runtime
# ==========================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ffmpeg \
       ca-certificates \
       libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /jellyfin

COPY --from=server-build /out/server/ /jellyfin/
COPY --from=web-build /src/web/dist/ /jellyfin/jellyfin-web/

RUN mkdir -p /config /cache /media \
    && chown -R 10001:10001 \
       /jellyfin /config /cache /media

ENV ASPNETCORE_URLS=http://0.0.0.0:8096 \
    JELLYFIN_DATA_DIR=/config \
    JELLYFIN_CONFIG_DIR=/config/config \
    JELLYFIN_CACHE_DIR=/cache \
    JELLYFIN_WEB_DIR=/jellyfin/jellyfin-web

USER 10001:10001

EXPOSE 8096

VOLUME ["/config", "/cache", "/media"]

ENTRYPOINT ["dotnet", "/jellyfin/jellyfin.dll"]
