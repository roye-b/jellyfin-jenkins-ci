
FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ffmpeg \
       ca-certificates \
       libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /jellyfin

COPY docker-context/server/ /jellyfin/
COPY docker-context/web/ /jellyfin/jellyfin-web/
RUN mkdir -p /config /cache /media \
    && chown -R 10001:10001 /jellyfin /config /cache /media
ENV ASPNETCORE_URLS=http://0.0.0.0:8096 \
    JELLYFIN_DATA_DIR=/config \
    JELLYFIN_CONFIG_DIR=/config/config \
    JELLYFIN_CACHE_DIR=/cache \
    JELLYFIN_WEB_DIR=/jellyfin/jellyfin-web
    
USER 10001:10001

EXPOSE 8096

VOLUME ["/config", "/cache", "/media"]

ENTRYPOINT ["dotnet", "/jellyfin/jellyfin.dll"]
