# Roblox Script Auto Updater

A professional Windows application that automatically checks for updates to the Universal Roblox Script and installs them with a beautiful progress bar interface.

## Features

✨ **Automatic Update Detection** - Checks GitHub releases for the latest version
📊 **Real-time Progress Bar** - Visual feedback during download and installation
🔄 **Automatic Backup** - Creates backup of current script before updating
📝 **Detailed Logging** - Shows all operations in real-time
🎨 **Modern GUI** - Clean, professional Windows interface
⚡ **Fast & Reliable** - Efficient download with progress tracking

## Screenshots

The updater features:
- Large, easy-to-read version display
- Real-time status updates
- Progress bar showing download/install progress
- Detailed log window showing all operations
- Modern flat design with blue accents

## Requirements

- Windows 10/11
- .NET 6.0 Runtime or SDK
- Internet connection for update checks

## Building the Executable

### Option 1: Using Visual Studio 2022

1. Open `UpdateChecker.csproj` in Visual Studio 2022
2. Select **Release** configuration
3. Right-click project → **Publish**
4. Choose **Folder** publish target
5. Click **Publish**
6. Find the .exe in `bin/Release/net6.0-windows/publish/`

### Option 2: Using .NET CLI (Command Line)

```bash
# Navigate to UpdateChecker directory
cd UpdateChecker

# Restore dependencies
dotnet restore

# Build Release version
dotnet build -c Release

# Publish as self-contained executable (includes .NET runtime)
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true

# The executable will be in: bin/Release/net6.0-windows/win-x64/publish/RobloxScriptUpdater.exe
```

### Option 3: Framework-Dependent Build (smaller file size)

```bash
# Publish framework-dependent (requires .NET 6.0 installed on target machine)
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true

# Output: bin/Release/net6.0-windows/win-x64/publish/RobloxScriptUpdater.exe
```

## Usage

### Running the Updater

1. **Simple Usage** (place in same folder as script):
   ```
   RobloxScriptUpdater.exe
   ```

2. **Custom Script Path** (command line argument):
   ```
   RobloxScriptUpdater.exe "C:\Path\To\Your\Script.lua"
   ```

3. **GUI Instructions**:
   - Click "Check for Updates" button
   - If update available, click "Yes" to download
   - Progress bar shows download and installation progress
   - Backup is automatically created
   - Script is updated automatically

## How It Works

1. **Version Detection**
   - Reads VERSION variable from local Lua script
   - Queries GitHub API for latest release
   - Falls back to main branch if no releases exist

2. **Update Check**
   - Compares local version with latest GitHub version
   - Notifies user if update is available

3. **Download**
   - Downloads latest script from GitHub releases
   - Shows real-time progress in progress bar
   - Saves to temporary location

4. **Installation**
   - Creates backup of current script (.backup extension)
   - Replaces old script with new version
   - Cleans up temporary files
   - Updates version display

5. **Safety**
   - Always creates backup before updating
   - Validates download before installation
   - Error handling with user-friendly messages

## Configuration

The updater is configured in `Program.cs`:

```csharp
string scriptPath = "ESPAIMBOTWALLBANGROBLOX.lua";  // Default script name
string repoOwner = "compiledkernel-idk";            // GitHub username
string repoName = "universal-roblox-script";        // Repository name
```

## Troubleshooting

### "No updates available" but you know there's an update
- Check that the VERSION in the Lua script matches the release tag
- Verify GitHub releases are properly tagged (e.g., "v1.0.1")
- Check internet connection

### Update fails
- Ensure you have write permissions to the script folder
- Check that the script file isn't in use by another program
- Review the log window for specific error messages

### Executable won't run
- Install .NET 6.0 Runtime from Microsoft
- Or use the self-contained build which includes runtime

### Can't find the executable after building
- Check `UpdateChecker/bin/Release/net6.0-windows/publish/`
- For self-contained: `bin/Release/net6.0-windows/win-x64/publish/`

## File Structure

```
UpdateChecker/
├── UpdateChecker.csproj      # Project configuration
├── Program.cs                # Application entry point
├── UpdaterForm.cs            # Main GUI and update logic
└── README.md                 # This file
```

## Version Format

The updater expects version strings in the Lua script like:
```lua
local VERSION = "1.0.0"
```

GitHub releases should be tagged as:
- `v1.0.0` or `1.0.0`

## Advanced Features

### Automatic Backup
Every update creates a backup file with `.backup` extension. You can manually restore by:
```bash
copy ESPAIMBOTWALLBANGROBLOX.lua.backup ESPAIMBOTWALLBANGROBLOX.lua
```

### Log Details
The log window shows:
- Timestamp for each operation
- Current and latest version info
- Download URL
- File operations (backup, install)
- Any errors encountered

### Progress Bar Breakdown
- 0-20%: Checking for updates
- 20-80%: Downloading (scales with download progress)
- 80-100%: Installing and cleanup

## Building Distribution Package

To create a distribution-ready package:

```bash
# Build self-contained single-file executable
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true

# Copy to distribution folder
mkdir dist
copy bin\Release\net6.0-windows\win-x64\publish\RobloxScriptUpdater.exe dist\

# Include the main script
copy ..\ESPAIMBOTWALLBANGROBLOX.lua dist\
```

Users can then run `RobloxScriptUpdater.exe` from the `dist` folder.

## License

Same as main project (MIT License)

## Support

For issues or questions:
- GitHub Issues: [compiledkernel-idk/universal-roblox-script](https://github.com/compiledkernel-idk/universal-roblox-script/issues)
