using System.Windows.Forms;

namespace VolvoxGrid.DotNet.Sample
{
    internal static partial class AppBootstrap
    {
        public static partial void Initialize()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
        }
    }
}
