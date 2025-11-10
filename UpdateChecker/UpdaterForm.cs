using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json.Linq;

namespace UpdateChecker
{
    public partial class UpdaterForm : Form
    {
        private readonly string scriptPath;
        private readonly string repoOwner;
        private readonly string repoName;
        private readonly HttpClient httpClient;

        private Label statusLabel;
        private ProgressBar progressBar;
        private Button checkUpdateButton;
        private Button closeButton;
        private Label versionLabel;
        private TextBox logTextBox;

        private string currentVersion = "1.0.0";
        private string latestVersion = "";
        private string downloadUrl = "";

        public UpdaterForm(string scriptPath, string repoOwner, string repoName)
        {
            this.scriptPath = Path.GetFullPath(scriptPath);
            this.repoOwner = repoOwner;
            this.repoName = repoName;
            this.httpClient = new HttpClient();
            this.httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("RobloxScriptUpdater/1.0");

            InitializeComponent();
            LoadCurrentVersion();
        }

        private void InitializeComponent()
        {
            this.Text = "Roblox Script Auto Updater";
            this.Size = new Size(600, 450);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.BackColor = Color.FromArgb(240, 240, 240);

            // Title Label
            Label titleLabel = new Label
            {
                Text = "Universal Roblox Script Updater",
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                Location = new Point(20, 20),
                Size = new Size(550, 35),
                TextAlign = ContentAlignment.MiddleCenter,
                ForeColor = Color.FromArgb(0, 120, 215)
            };
            this.Controls.Add(titleLabel);

            // Version Label
            versionLabel = new Label
            {
                Text = $"Current Version: {currentVersion}",
                Font = new Font("Segoe UI", 10),
                Location = new Point(20, 65),
                Size = new Size(550, 25),
                TextAlign = ContentAlignment.MiddleCenter
            };
            this.Controls.Add(versionLabel);

            // Status Label
            statusLabel = new Label
            {
                Text = "Ready to check for updates",
                Font = new Font("Segoe UI", 10),
                Location = new Point(20, 100),
                Size = new Size(550, 25),
                TextAlign = ContentAlignment.MiddleLeft
            };
            this.Controls.Add(statusLabel);

            // Progress Bar
            progressBar = new ProgressBar
            {
                Location = new Point(20, 135),
                Size = new Size(550, 30),
                Style = ProgressBarStyle.Continuous,
                Minimum = 0,
                Maximum = 100,
                Value = 0
            };
            this.Controls.Add(progressBar);

            // Log TextBox
            logTextBox = new TextBox
            {
                Location = new Point(20, 175),
                Size = new Size(550, 180),
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Font = new Font("Consolas", 9),
                BackColor = Color.White
            };
            this.Controls.Add(logTextBox);

            // Check Update Button
            checkUpdateButton = new Button
            {
                Text = "Check for Updates",
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Location = new Point(20, 370),
                Size = new Size(260, 40),
                BackColor = Color.FromArgb(0, 120, 215),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };
            checkUpdateButton.FlatAppearance.BorderSize = 0;
            checkUpdateButton.Click += async (s, e) => await CheckAndInstallUpdate();
            this.Controls.Add(checkUpdateButton);

            // Close Button
            closeButton = new Button
            {
                Text = "Close",
                Font = new Font("Segoe UI", 10),
                Location = new Point(310, 370),
                Size = new Size(260, 40),
                BackColor = Color.FromArgb(120, 120, 120),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };
            closeButton.FlatAppearance.BorderSize = 0;
            closeButton.Click += (s, e) => this.Close();
            this.Controls.Add(closeButton);
        }

        private void LoadCurrentVersion()
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
                                versionLabel.Text = $"Current Version: {currentVersion}";
                                LogMessage($"Loaded current version: {currentVersion}");
                                return;
                            }
                        }
                    }
                }
                LogMessage($"Script file found at: {scriptPath}");
                LogMessage("No version info found in script, using default: 1.0.0");
            }
            catch (Exception ex)
            {
                LogMessage($"Error loading version: {ex.Message}");
            }
        }

        private async Task CheckAndInstallUpdate()
        {
            checkUpdateButton.Enabled = false;
            progressBar.Value = 0;
            statusLabel.Text = "Checking for updates...";

            try
            {
                // Step 1: Check for updates (20%)
                LogMessage("Checking GitHub for latest release...");
                progressBar.Value = 10;

                bool updateAvailable = await CheckForUpdate();
                progressBar.Value = 20;

                if (!updateAvailable)
                {
                    statusLabel.Text = "You have the latest version!";
                    progressBar.Value = 100;
                    LogMessage("No updates available.");
                    MessageBox.Show("You are already using the latest version!", "Up to Date",
                        MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }

                // Ask user if they want to update
                DialogResult result = MessageBox.Show(
                    $"A new version ({latestVersion}) is available!\n\nCurrent: {currentVersion}\nLatest: {latestVersion}\n\nWould you like to download and install it?",
                    "Update Available",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question);

                if (result != DialogResult.Yes)
                {
                    statusLabel.Text = "Update cancelled by user";
                    LogMessage("Update cancelled by user.");
                    return;
                }

                // Step 2: Download update (60%)
                statusLabel.Text = "Downloading update...";
                LogMessage($"Downloading from: {downloadUrl}");
                string tempFile = await DownloadUpdate();
                progressBar.Value = 80;

                // Step 3: Install update (20%)
                statusLabel.Text = "Installing update...";
                LogMessage("Installing update...");
                await InstallUpdate(tempFile);
                progressBar.Value = 100;

                statusLabel.Text = "Update completed successfully!";
                LogMessage($"Successfully updated to version {latestVersion}");
                currentVersion = latestVersion;
                versionLabel.Text = $"Current Version: {currentVersion}";

                MessageBox.Show($"Update completed successfully!\n\nNew version: {latestVersion}",
                    "Update Successful", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                statusLabel.Text = "Update failed!";
                LogMessage($"ERROR: {ex.Message}");
                MessageBox.Show($"Update failed:\n\n{ex.Message}", "Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                checkUpdateButton.Enabled = true;
            }
        }

        private async Task<bool> CheckForUpdate()
        {
            try
            {
                string apiUrl = $"https://api.github.com/repos/{repoOwner}/{repoName}/releases/latest";
                HttpResponseMessage response = await httpClient.GetAsync(apiUrl);

                if (!response.IsSuccessStatusCode)
                {
                    // No releases yet, try to get the raw file from main branch
                    LogMessage("No releases found, checking main branch...");
                    return await CheckMainBranch();
                }

                string jsonResponse = await response.Content.ReadAsStringAsync();
                JObject releaseData = JObject.Parse(jsonResponse);

                latestVersion = releaseData["tag_name"]?.ToString().TrimStart('v') ?? "";

                if (string.IsNullOrEmpty(latestVersion))
                {
                    LogMessage("Could not parse version from release");
                    return false;
                }

                LogMessage($"Latest version on GitHub: {latestVersion}");
                LogMessage($"Current version: {currentVersion}");

                // Find the .lua file in assets
                JArray assets = (JArray)releaseData["assets"];
                foreach (JObject asset in assets)
                {
                    string name = asset["name"]?.ToString() ?? "";
                    if (name.EndsWith(".lua", StringComparison.OrdinalIgnoreCase))
                    {
                        downloadUrl = asset["browser_download_url"]?.ToString() ?? "";
                        LogMessage($"Found script asset: {name}");
                        break;
                    }
                }

                if (string.IsNullOrEmpty(downloadUrl))
                {
                    // Fall back to raw GitHub URL
                    downloadUrl = $"https://raw.githubusercontent.com/{repoOwner}/{repoName}/main/ESPAIMBOTWALLBANGROBLOX.lua";
                    LogMessage("No asset found, using raw GitHub URL");
                }

                return CompareVersions(currentVersion, latestVersion) < 0;
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to check for updates: {ex.Message}");
            }
        }

        private async Task<bool> CheckMainBranch()
        {
            try
            {
                // Get the raw file from main branch
                downloadUrl = $"https://raw.githubusercontent.com/{repoOwner}/{repoName}/main/ESPAIMBOTWALLBANGROBLOX.lua";
                HttpResponseMessage response = await httpClient.GetAsync(downloadUrl);

                if (!response.IsSuccessStatusCode)
                {
                    LogMessage("Could not access main branch");
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
                LogMessage($"Remote version: {remoteVersion}");

                return CompareVersions(currentVersion, remoteVersion) < 0;
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to check main branch: {ex.Message}");
            }
        }

        private async Task<string> DownloadUpdate()
        {
            try
            {
                string tempFile = Path.Combine(Path.GetTempPath(), "script_update.lua");

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

                        while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                        {
                            await fileStream.WriteAsync(buffer, 0, bytesRead);
                            totalRead += bytesRead;

                            if (totalBytes.HasValue)
                            {
                                int progress = 20 + (int)((totalRead * 60) / totalBytes.Value);
                                progressBar.Value = Math.Min(progress, 80);
                            }
                        }
                    }
                }

                LogMessage($"Downloaded to: {tempFile}");
                return tempFile;
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to download update: {ex.Message}");
            }
        }

        private async Task InstallUpdate(string tempFile)
        {
            try
            {
                // Create backup
                string backupPath = scriptPath + ".backup";
                if (File.Exists(scriptPath))
                {
                    File.Copy(scriptPath, backupPath, true);
                    LogMessage($"Created backup: {backupPath}");
                }

                // Install update
                await Task.Run(() =>
                {
                    File.Copy(tempFile, scriptPath, true);
                });

                LogMessage($"Updated script: {scriptPath}");

                // Clean up temp file
                File.Delete(tempFile);
                LogMessage("Cleaned up temporary files");
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to install update: {ex.Message}");
            }
        }

        private int CompareVersions(string v1, string v2)
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

        private void LogMessage(string message)
        {
            if (logTextBox.InvokeRequired)
            {
                logTextBox.Invoke(new Action(() => LogMessage(message)));
                return;
            }

            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            logTextBox.AppendText($"[{timestamp}] {message}\r\n");
            logTextBox.SelectionStart = logTextBox.Text.Length;
            logTextBox.ScrollToCaret();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                httpClient?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
