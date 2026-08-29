# syntax=docker/dockerfile:1
#
# Multi-stage build for the ChatServer (ASP.NET Core SignalR hub, .NET 10).
#
# Build context must be this folder (server/ChatServer):
#   docker build -t chatserver:local server/ChatServer
#
# Run example (Linux/Mac, reach the host Postgres via host.docker.internal):
#   docker run -d --name chatserver -p 5298:8080 \
#     -e ConnectionStrings__Default="Host=host.docker.internal;Port=5432;Database=chatdb;Username=postgres;Password=****" \
#     -e Jwt__Key="<a-long-random-secret>" \
#     -e Cors__Origins="https://fairdao-coder.github.io" \
#     -v chat-uploads:/app/uploads \
#     chatserver:local
#
# NOTE: the app's default connection string points at "Host=localhost" which,
# inside the container, means the container itself — NOT your host Postgres.
# Always override ConnectionStrings__Default when running in Docker.

# ---- 1. Build ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore in its own layer so the (large) NuGet graph is cached.
COPY ChatServer.csproj .
RUN dotnet restore

# Copy the rest and publish a framework-dependent, self-contained-free release.
COPY . .
RUN dotnet publish ChatServer.csproj -c Release -o /app/publish --no-restore

# ---- 2. Runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# .NET 8+ Kestrel default listens on 8080; be explicit for clarity.
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Uploaded media is written under /app/uploads — mount a volume to persist it.
VOLUME /app/uploads

COPY --from=build /app/publish .

# Override at runtime via environment variables:
#   ConnectionStrings__Default  -> PostgreSQL connection string
#   Jwt__Key / Jwt__Issuer / Jwt__Audience
#   Cors__Origins               -> space-or-comma separated allowed origins
ENTRYPOINT ["dotnet", "ChatServer.dll"]
