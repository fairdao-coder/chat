taskkill /f /im chatserver.exe
taskkill /f /im adminserver.exe
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8299"') do taskkill /F /PID %%a
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8298"') do taskkill /F /PID %%a
dotnet build  -c Debug .\server\AdminServer\AdminServer.csproj
dotnet build -c Debug .\server\ChatServer\ChatServer.csproj 
start dotnet run --urls="http://0.0.0.0:5299" --project .\server\AdminServer\AdminServer.csproj --cors
timeout /t 8 /nobreak
start dotnet run --urls="http://0.0.0.0:5298" --project .\server\ChatServer\ChatServer.csproj  --cors
pause
