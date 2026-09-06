cd %~dp0client\flutter_chat
call flutter.bat build web 
REM --release
cd %~dp0client\flutter_admin
call flutter.bat build web 
REM --release
pause
