cd %~dp0client\flutter_chat
flutter.bat build web --release
cd %~dp0client\flutter_admin
flutter.bat build web --release
pause
