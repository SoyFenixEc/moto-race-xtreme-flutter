@echo off
echo ========================================
echo  Moto Race Xtreme - Build Android APK/AAB
echo ========================================

REM Set your Flutter SDK path here
set FLUTTER=C:\flutter\bin\flutter.bat

echo Cleaning...
%FLUTTER% clean

echo Getting dependencies...
%FLUTTER% pub get

echo Generating launcher icons...
%FLUTTER% pub run flutter_launcher_icons

echo.
echo ========================================
echo  Build Options:
echo  1) APK (debug)
echo  2) APK (release)
echo  3) AAB (release - for Play Store)
echo ========================================
set /p OPTION="Select option (1-3): "

if "%OPTION%"=="1" (
    echo Building APK debug...
    %FLUTTER% build apk --debug
) else if "%OPTION%"=="2" (
    echo Building APK release...
    %FLUTTER% build apk --release
) else if "%OPTION%"=="3" (
    echo Building AAB release...
    %FLUTTER% build appbundle --release
) else (
    echo Invalid option
)

echo.
echo Done!
pause
