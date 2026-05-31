using Microsoft.UI.Xaml;

namespace PaperBanana.WinUI;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
        UnhandledException += (_, error) =>
        {
            try
            {
                File.WriteAllText(
                    Path.Combine(Path.GetTempPath(), "paperbanana-winui-crash.log"),
                    error.Exception?.ToString() ?? error.Message);
            }
            catch
            {
                // Best effort startup diagnostics.
            }
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            _window = new MainWindow();
            _window.Activate();
        }
        catch (Exception error)
        {
            File.WriteAllText(Path.Combine(Path.GetTempPath(), "paperbanana-winui-crash.log"), error.ToString());
            throw;
        }
    }
}
