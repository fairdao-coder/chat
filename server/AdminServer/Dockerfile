# 多阶段构建：.NET 10 SDK 编译，ASP.NET 10 运行时运行
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY AdminServer.csproj .
RUN dotnet restore AdminServer.csproj
COPY . .
RUN dotnet publish AdminServer.csproj -c Release -o /app/out

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 8080
VOLUME /app/uploads
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENTRYPOINT ["dotnet", "AdminServer.dll"]
