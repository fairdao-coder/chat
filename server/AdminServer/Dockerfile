# 多阶段构建：.NET 10 SDK 编译，ASP.NET 10 运行时运行
# Build context 必须是 server/ 目录（这样才能访问 Chat.Shared 项目引用）：
#   docker build -f AdminServer/Dockerfile -t adminserver:local server
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
# IMPORTANT: build context must be the server/ directory, not this file's directory.
COPY . .
RUN test -f AdminServer/AdminServer.csproj || \
    (echo "ERROR: build context is not server/ directory. Run from server/: docker build -f AdminServer/Dockerfile -t adminserver ." && exit 1)
RUN dotnet restore AdminServer/AdminServer.csproj
RUN dotnet publish AdminServer/AdminServer.csproj -c Release -o /app/out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 8080
VOLUME /app/uploads
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENTRYPOINT ["dotnet", "AdminServer.dll"]
