@echo off
chcp 65001
cls
echo ================================================
echo Rahero Terminal - Build and Deploy
echo ================================================
echo.

set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set FLUTTER_BIN=D:\dev\flutter\bin\flutter.bat

echo [1/3] Cleaning old build...
call "%FLUTTER_BIN%" clean
echo.

echo [2/3] Building Windows release...
call "%FLUTTER_BIN%" build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    pause
    exit /b 1
)
echo.

echo [3/3] Copying files to desktop...
xcopy "build\windows\x64\runner\Release\*" "D:\??\16235\Desktop\?????\" /E /Y /I
echo.

echo Done! New version deployed.
pause
