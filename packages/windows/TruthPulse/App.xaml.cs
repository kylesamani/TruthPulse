using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using Hardcodet.Wpf.TaskbarNotification;

namespace TruthPulse;

public partial class App : Application
{
    public static App? Instance { get; private set; }

    private MainWindow? _mainWindow;
    private TaskbarIcon? _trayIcon;
    private bool _windowVisible;
    private bool _isQuitting;
    private bool _suppressDeactivate;
    private readonly AutoUpdater _updater = new();

    // --- Win32 P/Invoke for global hotkey ---
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    private const int HotkeyId = 9001;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint VK_K = 0x4B;
    private const int WM_HOTKEY = 0x0312;

    private HotkeyConfig _hotkeyConfig = new()
    {
        Modifiers = MOD_CONTROL | MOD_SHIFT,
        Key = VK_K
    };

    private HwndSource? _hwndSource;

    public App()
    {
        Instance = this;
        DispatcherUnhandledException += (_, args) =>
        {
            MessageBox.Show($"Error: {args.Exception}", "TruthPulse Error");
            args.Handled = true;
        };
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        LoadHotkeyConfig();

        _mainWindow = new MainWindow();

        try
        {
            SetupTrayIcon();
        }
        catch
        {
            // Tray icon is non-critical, continue without it
        }

        _mainWindow.Closing += MainWindow_Closing;
        _mainWindow.Deactivated += (_, _) =>
        {
            if (_windowVisible && !_suppressDeactivate)
            {
                _mainWindow.Hide();
                _windowVisible = false;
            }
        };
        _mainWindow.Show();
        _windowVisible = true;

        _ = _updater.CheckSilentlyAsync();

        try
        {
            var helper = new WindowInteropHelper(_mainWindow);
            var hwnd = helper.EnsureHandle();
            _hwndSource = HwndSource.FromHwnd(hwnd);
            _hwndSource?.AddHook(WndProc);
            RegisterHotKey(hwnd, HotkeyId, _hotkeyConfig.Modifiers, _hotkeyConfig.Key);
        }
        catch
        {
            // Hotkey registration is non-critical
        }
    }

    private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (!_isQuitting)
        {
            e.Cancel = true;
            _mainWindow?.Hide();
            _windowVisible = false;
        }
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY && wParam.ToInt32() == HotkeyId)
        {
            ToggleWindow();
            handled = true;
        }
        return IntPtr.Zero;
    }

    private void SetupTrayIcon()
    {
        _trayIcon = new TaskbarIcon
        {
            IconSource = new BitmapImage(new Uri("pack://application:,,,/Assets/tray-icon.ico")),
            ToolTipText = "TruthPulse"
        };

        var contextMenu = new System.Windows.Controls.ContextMenu();

        var changeHotkeyItem = new System.Windows.Controls.MenuItem { Header = "Change shortcut..." };
        changeHotkeyItem.Click += (_, _) => ShowChangeHotkeyDialog();
        contextMenu.Items.Add(changeHotkeyItem);

        contextMenu.Items.Add(new System.Windows.Controls.Separator());

        var feedbackItem = new System.Windows.Controls.MenuItem { Header = "Provide feedback / report bugs" };
        feedbackItem.Click += (_, _) =>
        {
            var url = "https://mail.google.com/mail/?view=cm&to=truthpulse@kylesamani.com&su=TruthPulse%20Feedback";
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
            catch { /* ignore */ }
        };
        contextMenu.Items.Add(feedbackItem);

        var updateItem = new System.Windows.Controls.MenuItem { Header = "Check for Updates" };
        updateItem.Click += async (_, _) =>
        {
            _suppressDeactivate = true;
            try { await _updater.CheckManuallyAsync(); }
            finally { _suppressDeactivate = false; }
        };
        contextMenu.Items.Add(updateItem);

        contextMenu.Items.Add(new System.Windows.Controls.Separator());

        var quitItem = new System.Windows.Controls.MenuItem { Header = "Quit TruthPulse" };
        quitItem.Click += (_, _) => { _isQuitting = true; Shutdown(); };
        contextMenu.Items.Add(quitItem);

        _trayIcon.ContextMenu = contextMenu;
        _trayIcon.TrayMouseDoubleClick += (_, _) => ToggleWindow();
    }

    private void ToggleWindow()
    {
        if (_mainWindow == null) return;

        if (_windowVisible)
        {
            _mainWindow.Hide();
            _windowVisible = false;
        }
        else
        {
            _mainWindow.Show();

            var workArea = SystemParameters.WorkArea;
            _mainWindow.Left = workArea.Right - _mainWindow.Width - 12;
            _mainWindow.Top = workArea.Bottom - _mainWindow.Height - 12;

            _mainWindow.Activate();
            _mainWindow.FocusSearch();
            _windowVisible = true;

            var helper = new WindowInteropHelper(_mainWindow);
            SetForegroundWindow(helper.Handle);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_mainWindow != null)
        {
            try
            {
                var helper = new WindowInteropHelper(_mainWindow);
                UnregisterHotKey(helper.Handle, HotkeyId);
            }
            catch { }
        }
        _trayIcon?.Dispose();
        _updater.LaunchPendingUpdate();
        base.OnExit(e);
    }

    private string FormatHotkey()
    {
        var parts = new List<string>();
        if ((_hotkeyConfig.Modifiers & MOD_CONTROL) != 0) parts.Add("Ctrl");
        if ((_hotkeyConfig.Modifiers & MOD_SHIFT) != 0) parts.Add("Shift");
        parts.Add(((char)_hotkeyConfig.Key).ToString());
        return string.Join("+", parts);
    }

    private void ShowChangeHotkeyDialog()
    {
        _suppressDeactivate = true;
        try
        {
            ShowChangeHotkeyDialogCore();
        }
        finally
        {
            _suppressDeactivate = false;
        }
    }

    private void ShowChangeHotkeyDialogCore()
    {
        var dialog = new Window
        {
            Title = "Set Global Shortcut",
            Width = 340,
            Height = 160,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            ResizeMode = ResizeMode.NoResize
        };

        var stack = new System.Windows.Controls.StackPanel { Margin = new Thickness(20) };

        var label = new System.Windows.Controls.TextBlock
        {
            Text = "Press your desired shortcut key combination:",
            Margin = new Thickness(0, 0, 0, 12)
        };
        stack.Children.Add(label);

        var display = new System.Windows.Controls.TextBox
        {
            IsReadOnly = true,
            FontSize = 16,
            FontWeight = FontWeights.SemiBold,
            TextAlignment = TextAlignment.Center,
            Padding = new Thickness(8),
            Text = FormatHotkey()
        };
        stack.Children.Add(display);

        uint capturedMods = 0;
        uint capturedKey = 0;

        display.PreviewKeyDown += (_, ke) =>
        {
            ke.Handled = true;
            var key = ke.Key == Key.System ? ke.SystemKey : ke.Key;

            // Ignore modifier-only presses
            if (key == Key.LeftCtrl || key == Key.RightCtrl ||
                key == Key.LeftShift || key == Key.RightShift ||
                key == Key.LeftAlt || key == Key.RightAlt ||
                key == Key.LWin || key == Key.RWin)
                return;

            uint mods = 0;
            if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control)) mods |= MOD_CONTROL;
            if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) mods |= MOD_SHIFT;
            if (Keyboard.Modifiers.HasFlag(ModifierKeys.Alt)) mods |= 0x0001; // MOD_ALT

            if (mods == 0) return; // require at least one modifier

            capturedMods = mods;
            capturedKey = (uint)KeyInterop.VirtualKeyFromKey(key);

            var parts = new List<string>();
            if ((mods & MOD_CONTROL) != 0) parts.Add("Ctrl");
            if ((mods & 0x0001) != 0) parts.Add("Alt");
            if ((mods & MOD_SHIFT) != 0) parts.Add("Shift");
            parts.Add(key.ToString());
            display.Text = string.Join("+", parts);
        };

        var btnPanel = new System.Windows.Controls.StackPanel
        {
            Orientation = System.Windows.Controls.Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 12, 0, 0)
        };

        var saveBtn = new System.Windows.Controls.Button
        {
            Content = "Save",
            Padding = new Thickness(16, 4, 16, 4),
            Margin = new Thickness(0, 0, 8, 0)
        };
        saveBtn.Click += (_, _) =>
        {
            if (capturedKey == 0) { dialog.Close(); return; }

            // Unregister old hotkey
            if (_mainWindow != null)
            {
                try
                {
                    var helper = new WindowInteropHelper(_mainWindow);
                    UnregisterHotKey(helper.Handle, HotkeyId);
                }
                catch { }
            }

            _hotkeyConfig = new HotkeyConfig { Modifiers = capturedMods, Key = capturedKey };
            SaveHotkeyConfig();

            // Register new hotkey
            if (_mainWindow != null)
            {
                try
                {
                    var helper = new WindowInteropHelper(_mainWindow);
                    RegisterHotKey(helper.Handle, HotkeyId, _hotkeyConfig.Modifiers, _hotkeyConfig.Key);
                }
                catch { }
            }

            dialog.Close();
        };
        btnPanel.Children.Add(saveBtn);

        var cancelBtn = new System.Windows.Controls.Button
        {
            Content = "Cancel",
            Padding = new Thickness(16, 4, 16, 4)
        };
        cancelBtn.Click += (_, _) => dialog.Close();
        btnPanel.Children.Add(cancelBtn);

        stack.Children.Add(btnPanel);
        dialog.Content = stack;
        display.Focus();
        dialog.ShowDialog();
    }

    private void SaveHotkeyConfig()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var dir = Path.Combine(appData, "TruthPulse");
        Directory.CreateDirectory(dir);
        var settingsPath = Path.Combine(dir, "settings.json");

        try
        {
            var json = JsonSerializer.Serialize(_hotkeyConfig, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(settingsPath, json);
        }
        catch { }
    }

    private void LoadHotkeyConfig()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var settingsPath = Path.Combine(appData, "TruthPulse", "settings.json");

        if (!File.Exists(settingsPath)) return;

        try
        {
            var json = File.ReadAllText(settingsPath);
            var config = JsonSerializer.Deserialize<HotkeyConfig>(json);
            if (config != null)
                _hotkeyConfig = config;
        }
        catch
        {
            // Use defaults
        }
    }

    private sealed class HotkeyConfig
    {
        public uint Modifiers { get; set; } = MOD_CONTROL | MOD_SHIFT;
        public uint Key { get; set; } = VK_K;
    }

    private sealed class AutoUpdater
    {
        private const string CurrentVersion = "1.0.0";
        private const string ReleasesUrl = "https://api.github.com/repos/kylesamani/TruthPulse/releases/latest";

        private static readonly HttpClient Http = CreateHttpClient();
        private string? _pendingUpdatePath;

        private static HttpClient CreateHttpClient()
        {
            var client = new HttpClient();
            client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("TruthPulse", CurrentVersion));
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            return client;
        }

        public async Task CheckSilentlyAsync()
        {
            try
            {
                await CheckForUpdateAsync(silent: true);
            }
            catch
            {
                // Silent check — swallow all errors
            }
        }

        public async Task CheckManuallyAsync()
        {
            try
            {
                var found = await CheckForUpdateAsync(silent: false);
                if (!found)
                {
                    MessageBox.Show("You're up to date.", "TruthPulse", MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to check for updates:\n{ex.Message}", "TruthPulse", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private async Task<bool> CheckForUpdateAsync(bool silent)
        {
            var json = await Http.GetStringAsync(ReleasesUrl);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!root.TryGetProperty("tag_name", out var tagEl))
                return false;

            var remoteTag = tagEl.GetString()?.TrimStart('v', 'V') ?? "";
            if (!Version.TryParse(remoteTag, out var remoteVersion))
                return false;
            if (!Version.TryParse(CurrentVersion, out var localVersion))
                return false;
            if (remoteVersion <= localVersion)
                return false;

            // Find the Windows asset
            if (!root.TryGetProperty("assets", out var assets))
                return false;

            string? assetUrl = null;
            string? assetName = null;
            foreach (var asset in assets.EnumerateArray())
            {
                var name = asset.GetProperty("name").GetString() ?? "";
                var nameLower = name.ToLowerInvariant();
                if (nameLower.Contains("windows") || nameLower.EndsWith(".exe") || nameLower.EndsWith(".zip"))
                {
                    assetUrl = asset.GetProperty("browser_download_url").GetString();
                    assetName = name;
                    break;
                }
            }

            if (assetUrl == null || assetName == null)
                return false;

            if (!silent)
            {
                var result = MessageBox.Show(
                    $"A new version ({remoteTag}) is available. Download now?",
                    "TruthPulse Update",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Information);
                if (result != MessageBoxResult.Yes)
                    return true;
            }

            // Download in background
            var tempDir = Path.Combine(Path.GetTempPath(), "TruthPulse");
            Directory.CreateDirectory(tempDir);
            var destPath = Path.Combine(tempDir, assetName);

            using var response = await Http.GetAsync(assetUrl);
            response.EnsureSuccessStatusCode();
            using var fs = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None);
            await response.Content.CopyToAsync(fs);

            _pendingUpdatePath = destPath;

            if (!silent)
            {
                MessageBox.Show(
                    "Update downloaded. It will be installed when you quit TruthPulse.",
                    "TruthPulse",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }

            return true;
        }

        public void LaunchPendingUpdate()
        {
            if (_pendingUpdatePath == null || !File.Exists(_pendingUpdatePath))
                return;

            try
            {
                Process.Start(new ProcessStartInfo(_pendingUpdatePath) { UseShellExecute = true });
            }
            catch
            {
                // Best-effort launch
            }
        }
    }
}
