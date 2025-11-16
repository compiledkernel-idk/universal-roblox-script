using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;

namespace UpdateChecker
{
    class Program
    {
        private static readonly string repoOwner = "compiledkernel-idk";
        private static readonly string repoName = "universal-roblox-script";
        private static readonly HttpClient httpClient = new HttpClient();

        private static string scriptPath = "kernelscript.luau";
        private static string currentVersion = "1.0.0";
        private static string latestVersion = "";
        private static string downloadUrl = "";

        static async Task<int> Main(string[] args)
        {
            // Set up console
            Console.OutputEncoding = System.Text.Encoding.UTF8;
            httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("RobloxScriptUpdater/2.0");

            // Parse arguments
            if (args.Length > 0)
            {
                scriptPath = args[0];
            }

            try
            {
                PrintHeader();
                LoadCurrentVersion();

                WriteColored("\n[INFO] Checking for updates...\n", ConsoleColor.Cyan);

                bool updateAvailable = await CheckForUpdate();

                if (!updateAvailable)
                {
                    WriteColored("\n✓ You have the latest version!", ConsoleColor.Green);
                    WriteColored($"  Current version: {currentVersion}\n", ConsoleColor.Gray);
                    return 0;
                }

                WriteColored("\n[UPDATE AVAILABLE]\n", ConsoleColor.Yellow);
                WriteColored($"  Current version: {currentVersion}\n", ConsoleColor.Gray);
                WriteColored($"  Latest version:  {latestVersion}\n", ConsoleColor.Green);

                Console.Write("\nDo you want to download and install the update? (Y/n): ");
                string response = Console.ReadLine()?.Trim().ToLower() ?? "y";

                if (response == "n" || response == "no")
                {
                    WriteColored("\n[CANCELLED] Update cancelled by user.\n", ConsoleColor.Yellow);
                    return 0;
                }

                WriteColored("\n[DOWNLOAD] Downloading update...\n", ConsoleColor.Cyan);
                string tempFile = await DownloadUpdate();

                WriteColored("\n[INSTALL] Installing update...\n", ConsoleColor.Cyan);
                await InstallUpdate(tempFile);

                WriteColored("\n✓ Update completed successfully!", ConsoleColor.Green);
                WriteColored($"  Updated to version {latestVersion}\n", ConsoleColor.Gray);

                return 0;
            }
            catch (Exception ex)
            {
                WriteColored($"\n✗ ERROR: {ex.Message}\n", ConsoleColor.Red);
                return 1;
            }
        }

        private static void PrintHeader()
        {
            Console.Clear();
            WriteColored("╔════════════════════════════════════════════════╗\n", ConsoleColor.Cyan);
            WriteColored("║   Universal Roblox Script - Update Checker   ║\n", ConsoleColor.Cyan);
            WriteColored("╚════════════════════════════════════════════════╝\n", ConsoleColor.Cyan);
        }

        private static void LoadCurrentVersion()
        {
            try
            {
                if (File.Exists(scriptPath))
                {
                    string[] lines = File.ReadAllLines(scriptPath);
                    foreach (string line in lines)
                    {
                        if (line.Contains("VERSION") && line.Contains("="))
                        {
                            // Extract version from line like: local VERSION = "1.0.0"
                            int startIdx = line.IndexOf('"');
                            int endIdx = line.LastIndexOf('"');
                            if (startIdx >= 0 && endIdx > startIdx)
                            {
                                currentVersion = line.Substring(startIdx + 1, endIdx - startIdx - 1);
                                WriteColored($"[INFO] Script found: {scriptPath}\n", ConsoleColor.Gray);
                                WriteColored($"[INFO] Current version: {currentVersion}\n", ConsoleColor.Gray);
                                return;
                            }
                        }
                    }
                }
                WriteColored($"[WARN] No version info found in script, using default: {currentVersion}\n", ConsoleColor.Yellow);
            }
            catch (Exception ex)
            {
                WriteColored($"[WARN] Error loading version: {ex.Message}\n", ConsoleColor.Yellow);
            }
        }

        private static async Task<bool> CheckForUpdate()
        {
            try
            {
                string apiUrl = $"https://api.github.com/repos/{repoOwner}/{repoName}/releases/latest";
                HttpResponseMessage response = await httpClient.GetAsync(apiUrl);

                if (!response.IsSuccessStatusCode)
                {
                    WriteColored("[INFO] No releases found, checking main branch...\n", ConsoleColor.Gray);
                    return await CheckMainBranch();
                }

                string jsonResponse = await response.Content.ReadAsStringAsync();
                JObject releaseData = JObject.Parse(jsonResponse);

                latestVersion = releaseData["tag_name"]?.ToString().TrimStart('v') ?? "";

                if (string.IsNullOrEmpty(latestVersion))
                {
                    WriteColored("[WARN] Could not parse version from release\n", ConsoleColor.Yellow);
                    return false;
                }

                WriteColored($"[INFO] Latest release: {latestVersion}\n", ConsoleColor.Gray);

                // Find the .lua/.luau file in assets
                JArray assets = (JArray)releaseData["assets"];
                if (assets != null)
                {
                    foreach (JObject asset in assets)
                    {
                        string name = asset["name"]?.ToString() ?? "";
                        if (name.EndsWith(".lua", StringComparison.OrdinalIgnoreCase) ||
                            name.EndsWith(".luau", StringComparison.OrdinalIgnoreCase))
                        {
                            downloadUrl = asset["browser_download_url"]?.ToString() ?? "";
                            WriteColored($"[INFO] Found script asset: {name}\n", ConsoleColor.Gray);
                            break;
                        }
                    }
                }

                if (string.IsNullOrEmpty(downloadUrl))
                {
                    // Fall back to raw GitHub URL
                    downloadUrl = $"https://raw.githubusercontent.com/{repoOwner}/{repoName}/main/kernelscript.luau";
                    WriteColored("[INFO] Using raw GitHub URL\n", ConsoleColor.Gray);
                }

                return CompareVersions(currentVersion, latestVersion) < 0;
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to check for updates: {ex.Message}");
            }
        }

        private static async Task<bool> CheckMainBranch()
        {
            try
            {
                downloadUrl = $"https://raw.githubusercontent.com/{repoOwner}/{repoName}/main/kernelscript.luau";
                HttpResponseMessage response = await httpClient.GetAsync(downloadUrl);

                if (!response.IsSuccessStatusCode)
                {
                    WriteColored("[WARN] Could not access main branch\n", ConsoleColor.Yellow);
                    return false;
                }

                string content = await response.Content.ReadAsStringAsync();

                // Extract version from remote file
                string remoteVersion = "1.0.0";
                string[] lines = content.Split('\n');
                foreach (string line in lines)
                {
                    if (line.Contains("VERSION") && line.Contains("="))
                    {
                        int startIdx = line.IndexOf('"');
                        int endIdx = line.LastIndexOf('"');
                        if (startIdx >= 0 && endIdx > startIdx)
                        {
                            remoteVersion = line.Substring(startIdx + 1, endIdx - startIdx - 1);
                            break;
                        }
                    }
                }

                latestVersion = remoteVersion;
                WriteColored($"[INFO] Remote version: {remoteVersion}\n", ConsoleColor.Gray);

                return CompareVersions(currentVersion, remoteVersion) < 0;
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to check main branch: {ex.Message}");
            }
        }

        private static async Task<string> DownloadUpdate()
        {
            try
            {
                string tempFile = Path.Combine(Path.GetTempPath(), "script_update.luau");

                using (HttpResponseMessage response = await httpClient.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead))
                {
                    response.EnsureSuccessStatusCode();

                    long? totalBytes = response.Content.Headers.ContentLength;
                    using (Stream contentStream = await response.Content.ReadAsStreamAsync())
                    using (FileStream fileStream = new FileStream(tempFile, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true))
                    {
                        byte[] buffer = new byte[8192];
                        long totalRead = 0;
                        int bytesRead;

                        Console.Write("  Progress: [");
                        int lastProgress = 0;

                        while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                        {
                            await fileStream.WriteAsync(buffer, 0, bytesRead);
                            totalRead += bytesRead;

                            if (totalBytes.HasValue)
                            {
                                int progress = (int)((totalRead * 100) / totalBytes.Value);
                                int barLength = progress / 2; // 50 chars max

                                while (lastProgress < barLength)
                                {
                                    Console.Write("█");
                                    lastProgress++;
                                }
                            }
                        }

                        // Fill remaining progress bar
                        while (lastProgress < 50)
                        {
                            Console.Write("█");
                            lastProgress++;
                        }
                        Console.Write("] 100%\n");
                    }
                }

                WriteColored($"  Downloaded to: {tempFile}\n", ConsoleColor.Gray);
                return tempFile;
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to download update: {ex.Message}");
            }
        }

        private static async Task InstallUpdate(string tempFile)
        {
            try
            {
                // Create backup
                string backupPath = scriptPath + ".backup";
                if (File.Exists(scriptPath))
                {
                    File.Copy(scriptPath, backupPath, true);
                    WriteColored($"  ✓ Created backup: {backupPath}\n", ConsoleColor.Gray);
                }

                // Install update
                await Task.Run(() =>
                {
                    File.Copy(tempFile, scriptPath, true);
                });

                WriteColored($"  ✓ Updated script: {scriptPath}\n", ConsoleColor.Gray);

                // Clean up temp file
                File.Delete(tempFile);
                WriteColored("  ✓ Cleaned up temporary files\n", ConsoleColor.Gray);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to install update: {ex.Message}");
            }
        }

        private static int CompareVersions(string v1, string v2)
        {
            try
            {
                Version version1 = new Version(v1);
                Version version2 = new Version(v2);
                return version1.CompareTo(version2);
            }
            catch
            {
                // Fallback to string comparison
                return string.Compare(v1, v2, StringComparison.OrdinalIgnoreCase);
            }
        }

        private static void WriteColored(string text, ConsoleColor color)
        {
            ConsoleColor originalColor = Console.ForegroundColor;
            Console.ForegroundColor = color;
            Console.Write(text);
            Console.ForegroundColor = originalColor;
        }
    }
}
