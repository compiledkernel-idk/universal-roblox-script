#!/bin/bash

echo "============================================"
echo " Roblox Script Auto Updater - Build Script"
echo "============================================"
echo ""

# Check if dotnet is installed
if ! command -v dotnet &> /dev/null; then
    echo "ERROR: .NET SDK is not installed or not in PATH"
    echo "Please download and install .NET 6.0 SDK from:"
    echo "https://dotnet.microsoft.com/download/dotnet/6.0"
    exit 1
fi

echo "[1/4] Cleaning previous builds..."
rm -rf bin obj

echo "[2/4] Restoring dependencies..."
dotnet restore
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to restore dependencies"
    exit 1
fi

echo "[3/4] Building Release version..."
dotnet build -c Release
if [ $? -ne 0 ]; then
    echo "ERROR: Build failed"
    exit 1
fi

echo "[4/4] Publishing self-contained executable..."
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true
if [ $? -ne 0 ]; then
    echo "ERROR: Publish failed"
    exit 1
fi

echo ""
echo "============================================"
echo " BUILD SUCCESSFUL!"
echo "============================================"
echo ""
echo "Executable location:"
echo "bin/Release/net6.0-windows/win-x64/publish/RobloxScriptUpdater.exe"
echo ""
echo "File size:"
ls -lh bin/Release/net6.0-windows/win-x64/publish/RobloxScriptUpdater.exe | awk '{print $5, $9}'
echo ""
echo "You can now distribute this executable!"
echo ""
