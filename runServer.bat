for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8299"') do taskkill /F /PID %%a

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8298"') do taskkill /F /PID %%a

start dotnet run --project .\server\AdminServer\AdminServer.csproj --cors
timeout /t 8 /nobreak
start dotnet run --project .\server\ChatServer\ChatServer.csproj  --cors

pause