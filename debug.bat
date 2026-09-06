cd %~dp0client\flutter_chat
adb devices
flutter.bat run -d effc56 --dart-define=API_BASE=http://192.168.5.11:5298
pause