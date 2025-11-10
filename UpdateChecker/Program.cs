using System;
using System.Windows.Forms;

namespace UpdateChecker
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Parse command line arguments
            string scriptPath = args.Length > 0 ? args[0] : "ESPAIMBOTWALLBANGROBLOX.lua";
            string repoOwner = "compiledkernel-idk";
            string repoName = "universal-roblox-script";

            Application.Run(new UpdaterForm(scriptPath, repoOwner, repoName));
        }
    }
}
