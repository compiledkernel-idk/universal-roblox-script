# Roblox Script Update Checker (Console Version)

A fast, lightweight command-line tool that automatically checks for updates to the Universal Roblox Script and installs them with a beautiful console progress bar interface.

## Features

- Command-line interface (CMD/Terminal)
- Colored console output with status indicators
- Real-time download progress bar
- Automatic version detection from GitHub releases
- Automatic backup creation before updates
- Detailed logging of all operations
- Small, portable executable

## Requirements

- Windows 10/11 (for .exe)
- .NET 6.0 Runtime (or use self-contained build)
- Internet connection for update checks

## Building the Executable

### Quick Build (Recommended)

**Windows:**
```bash
cd UpdateChecker
build.bat
```

**Linux/Mac:**
```bash
cd UpdateChecker
chmod +x build.sh
./build.sh
```

The executable will be created at: `bin/Release/net6.0/win-x64/publish/UpdateChecker.exe`

### Manual Build Options

#### Option 1: Self-Contained (includes .NET runtime)

```bash
cd UpdateChecker
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

Output: `bin/Release/net6.0/win-x64/publish/UpdateChecker.exe`

#### Option 2: Framework-Dependent (smaller, requires .NET 6.0)

```bash
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true
```

## Usage

### Basic Usage

Place `UpdateChecker.exe` in the same folder as your `kernelscript.luau` file and run:

```cmd
UpdateChecker.exe
```

### Custom Script Path

Specify a different script file:

```cmd
UpdateChecker.exe "C:\Path\To\YourScript.luau"
```

### Example Output

```
╔════════════════════════════════════════════════╗
║   Universal Roblox Script - Update Checker   ║
╚════════════════════════════════════════════════╝

[INFO] Script found: kernelscript.luau
[INFO] Current version: 1.0.0

[INFO] Checking for updates...
[INFO] Latest release: 1.1.0

[UPDATE AVAILABLE]
  Current version: 1.0.0
  Latest version:  1.1.0

Do you want to download and install the update? (Y/n): y

[DOWNLOAD] Downloading update...
  Progress: [██████████████████████████████████████████████████] 100%
  Downloaded to: C:\Temp\script_update.luau

[INSTALL] Installing update...
  ✓ Created backup: kernelscript.luau.backup
  ✓ Updated script: kernelscript.luau
  ✓ Cleaned up temporary files

✓ Update completed successfully!
  Updated to version 1.1.0
```

## How It Works

1. **Version Detection**
   - Reads VERSION variable from your local Lua script
   - Example: `local VERSION = "1.0.0"`
   - Queries GitHub API for latest release

2. **Update Check**
   - Compares local version with latest GitHub version
   - Falls back to main branch if no releases exist
   - Uses semantic versioning for comparison

3. **Download**
   - Downloads latest script from GitHub releases
   - Shows real-time progress bar with download status
   - Saves to temporary location

4. **Installation**
   - Creates backup with `.backup` extension
   - Replaces old script with new version
   - Cleans up temporary files
   - Validates successful installation

5. **Safety Features**
   - Always creates backup before updating
   - Error handling with user-friendly messages
   - Returns exit codes (0 = success, 1 = error)

## Configuration

The updater is configured in `Program.cs`:

```csharp
private static readonly string repoOwner = "compiledkernel-idk";
private static readonly string repoName = "universal-roblox-script";
private static string scriptPath = "kernelscript.luau";
```

## Version Format

The updater expects version strings in your Lua script like:

```lua
local VERSION = "1.0.0"
-- or
local VERSION = "1.2.3"
```

GitHub releases should be tagged as:
- `v1.0.0` or `1.0.0`
- `v1.2.3` or `1.2.3`

## Exit Codes

- `0` - Success (no update needed or update completed)
- `1` - Error occurred

Example usage in batch scripts:
```batch
UpdateChecker.exe
if %ERRORLEVEL% EQU 0 (
    echo Update check successful
) else (
    echo Update check failed
)
```

## Troubleshooting

### "No updates available" but you know there's an update
- Check that the VERSION in the Lua script matches the release tag
- Verify GitHub releases are properly tagged (e.g., "v1.0.1")
- Check internet connection
- Run with `-v` flag for verbose output (if implemented)

### Update fails
- Ensure you have write permissions to the script folder
- Check that the script file isn't in use by another program
- Review console output for specific error messages
- Check the backup file was created (`.backup` extension)

### Executable won't run
- Install .NET 6.0 Runtime from Microsoft
- Or use the self-contained build which includes runtime
- Check Windows Defender/antivirus isn't blocking

### Permission denied errors
- Run as Administrator if needed
- Check file/folder permissions
- Ensure script file isn't read-only

## Advanced Features

### Automatic Backup
Every update creates a backup file with `.backup` extension.

Manual restore:
```cmd
copy kernelscript.luau.backup kernelscript.luau
```

### Batch Script Integration

Create an auto-update launcher:

```batch
@echo off
echo Checking for updates...
UpdateChecker.exe
if %ERRORLEVEL% EQU 0 (
    echo Starting script...
    start your_executor.exe kernelscript.luau
)
pause
```

## File Structure

```
UpdateChecker/
├── UpdateChecker.csproj    # Project configuration
├── Program.cs              # Main console application
├── build.bat               # Windows build script
├── build.sh                # Linux/Mac build script
└── README.md               # This file
```

## Building for Different Platforms

### Windows x64 (default)
```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

### Windows x86 (32-bit)
```bash
dotnet publish -c Release -r win-x86 --self-contained true -p:PublishSingleFile=true
```

### Linux x64
```bash
dotnet publish -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true
```

## Distribution Package

To create a distribution-ready package:

```bash
# Build the executable
cd UpdateChecker
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true

# Create distribution folder
mkdir dist
copy bin\Release\net6.0\win-x64\publish\UpdateChecker.exe dist\
copy ..\kernelscript.luau dist\
```

Users can then run `UpdateChecker.exe` from the `dist` folder.

## Differences from GUI Version

This console version:
- No GUI window - runs in CMD/Terminal
- Faster startup time
- Smaller file size
- Better for automation/scripting
- Works over SSH/remote connections
- Cleaner, more professional output

## License

Same as main project (MIT License)

## Support

For issues or questions:
- GitHub Issues: [compiledkernel-idk/universal-roblox-script](https://github.com/compiledkernel-idk/universal-roblox-script/issues)
