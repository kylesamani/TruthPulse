using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Interop;
using Hardcodet.Wpf.TaskbarNotification;

namespace TruthPulse;

public partial class App : Application
{
    public static App? Instance { get; private set; }

    private MainWindow? _mainWindow;
    private TaskbarIcon? _trayIcon;
    private bool _windowVisible;

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
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        LoadHotkeyConfig();

        _mainWindow = new MainWindow();

        SetupTrayIcon();

        _mainWindow.Show();
        _windowVisible = true;

        // Register hotkey after window has a handle
        var helper = new WindowInteropHelper(_mainWindow);
        _hwndSource = HwndSource.FromHwnd(helper.Handle);
        _hwndSource?.AddHook(WndProc);
        RegisterHotKey(helper.Handle, HotkeyId, _hotkeyConfig.Modifiers, _hotkeyConfig.Key);
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
            ToolTipText = "TruthPulse"
        };

        var contextMenu = new System.Windows.Controls.ContextMenu();

        var hotkeyItem = new System.Windows.Controls.MenuItem
        {
            Header = $"Shortcut: {FormatHotkey()}"
        };
        contextMenu.Items.Add(hotkeyItem);

        contextMenu.Items.Add(new System.Windows.Controls.Separator());

        var feedbackItem = new System.Windows.Controls.MenuItem { Header = "Provide feedback / report bugs" };
        feedbackItem.Click += (_, _) =>
        {
            var url = "https://mail.google.com/mail/?view=cm&to=iam@kylesamani.com&su=TruthPulse%20Feedback";
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
            catch { /* ignore */ }
        };
        contextMenu.Items.Add(feedbackItem);

        contextMenu.Items.Add(new System.Windows.Controls.Separator());

        var quitItem = new System.Windows.Controls.MenuItem { Header = "Quit TruthPulse" };
        quitItem.Click += (_, _) => Shutdown();
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
            var helper = new WindowInteropHelper(_mainWindow);
            UnregisterHotKey(helper.Handle, HotkeyId);
        }
        _trayIcon?.Dispose();
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
}
