
# Stage 1: Jellyfin Server Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS server-build
WORKDIR /src/server

# TODO: Copy server source, restore, build and publish

# Stage 2: Jellyfin Web Build
FROM node:20 AS web-build
WORKDIR /src/web

# TODO: Copy web source, npm ci and production build

# Stage 3: Jellyfin Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# TODO: Copy compiled server and web assets
# TODO: Install native libraries and FFmpeg
# TODO: Configure non-root user and writable paths
