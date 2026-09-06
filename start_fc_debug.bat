@echo off
cd /d %~dp0client\flutter_chat

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":30002"') do taskkill /F /PID %%a >nul 2>&1

start "" cmd /c "flutter.bat run -d web-server --web-port 30002 --dart-define=API_BASE=http://localhost:5298 > c:\Users\xbdki\code\chat\fc_dbg2.log 2> c:\Users\xbdki\code\chat\fc_dbg2_err.log"
