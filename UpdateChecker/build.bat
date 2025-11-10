@echo off
echo ============================================
echo  Roblox Script Auto Updater - Build Script
echo ============================================
echo.

:: Check if dotnet is installed
where dotnet >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: .NET SDK is not installed or not in PATH
    echo Please download and install .NET 6.0 SDK from:
    echo https://dotnet.microsoft.com/download/dotnet/6.0
    pause
    exit /b 1
)

echo [1/4] Cleaning previous builds...
if exist bin rmdir /s /q bin
if exist obj rmdir /s /q obj

echo [2/4] Restoring dependencies...
dotnet restore
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to restore dependencies
    pause
    exit /b 1
)

echo [3/4] Building Release version...
dotnet build -c Release
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo [4/4] Publishing self-contained executable...
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Publish failed
    pause
    exit /b 1
)

echo.
echo ============================================
echo  BUILD SUCCESSFUL!
echo ============================================
echo.
echo Executable location:
echo bin\Release\net6.0-windows\win-x64\publish\RobloxScriptUpdater.exe
echo.
echo File size:
dir "bin\Release\net6.0-windows\win-x64\publish\RobloxScriptUpdater.exe" | find "RobloxScriptUpdater.exe"
echo.
echo You can now distribute this executable!
echo.
pause
