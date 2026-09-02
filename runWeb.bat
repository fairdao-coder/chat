for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":30002"') do taskkill /F /PID %%a

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":30003"') do taskkill /F /PID %%a

REM cmd.exe /k \"cd /d \"%V\" && start http://127.0.0.1:30000 && http-server . -p 30000\
start "" msedge.exe http://localhost:30002 && start "" http-server  .\client\flutter_chat\build\web -p 30002 --cors
timeout /t 3
start "" chrome.exe http://localhost:30003 && http-server  .\client\flutter_admin\build\web -p 30003 --cors