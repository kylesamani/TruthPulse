using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows.Input;
using H.NotifyIcon;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

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

    private HotkeyConfig _hotkeyConfig = new()
    {
        Modifiers = MOD_CONTROL | MOD_SHIFT,
        Key = VK_K
    };

    public Microsoft.UI.Dispatching.DispatcherQueue? AppDispatcherQueue =>
        _mainWindow?.DispatcherQueue;

    public App()
    {
        Instance = this;
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        LoadHotkeyConfig();

        _mainWindow = new MainWindow();

        SetupTrayIcon();

        // Show window initially so we get a valid HWND for hotkey registration
        _mainWindow.Activate();
        _windowVisible = true;

        RegisterGlobalHotkey();
    }

    private void SetupTrayIcon()
    {
        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "TruthPulse - Kalshi Quick Search"
        };

        var contextMenu = new MenuFlyout();

        var hotkeyItem = new MenuFlyoutItem
        {
            Text = $"Shortcut: {FormatHotkey()}"
        };
        contextMenu.Items.Add(hotkeyItem);

        contextMenu.Items.Add(new MenuFlyoutSeparator());

        var feedbackItem = new MenuFlyoutItem { Text = "Provide feedback / report bugs" };
        feedbackItem.Click += (_, _) =>
        {
            var url = "https://mail.google.com/mail/?view=cm&to=iam@kylesamani.com&su=TruthPulse%20Feedback";
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
            catch { /* ignore */ }
        };
        contextMenu.Items.Add(feedbackItem);

        contextMenu.Items.Add(new MenuFlyoutSeparator());

        var quitItem = new MenuFlyoutItem { Text = "Quit TruthPulse" };
        quitItem.Click += (_, _) =>
        {
            Shutdown();
        };
        contextMenu.Items.Add(quitItem);

        _trayIcon.ContextFlyout = contextMenu;
        _trayIcon.LeftClickCommand = new SimpleCommand(ToggleWindow);
    }

    private void ToggleWindow()
    {
        if (_mainWindow == null) return;

        if (_windowVisible)
        {
            _mainWindow.AppWindow.Hide();
            _windowVisible = false;
        }
        else
        {
            _mainWindow.Activate();
            _mainWindow.BringToFront();
            _windowVisible = true;

            // Force foreground on Windows
            var hwnd = GetWindowHandle();
            if (hwnd != IntPtr.Zero)
                SetForegroundWindow(hwnd);
        }
    }

    private void RegisterGlobalHotkey()
    {
        var hwnd = GetWindowHandle();
        if (hwnd != IntPtr.Zero)
        {
            RegisterHotKey(hwnd, HotkeyId, _hotkeyConfig.Modifiers, _hotkeyConfig.Key);
        }
    }

    private IntPtr GetWindowHandle()
    {
        if (_mainWindow == null) return IntPtr.Zero;
        var windowId = _mainWindow.AppWindow.Id;
        return Microsoft.UI.Win32Interop.GetWindowFromWindowId(windowId);
    }

    public void OnHotkeyPressed()
    {
        ToggleWindow();
    }

    private void Shutdown()
    {
        var hwnd = GetWindowHandle();
        if (hwnd != IntPtr.Zero)
            UnregisterHotKey(hwnd, HotkeyId);

        _trayIcon?.Dispose();
        _mainWindow?.Close();
        Environment.Exit(0);
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

    /// <summary>
    /// Minimal ICommand for tray icon click binding.
    /// Named to avoid collision with CommunityToolkit.Mvvm.Input.RelayCommand.
    /// </summary>
    private sealed class SimpleCommand : ICommand
    {
        private readonly Action _execute;
        public SimpleCommand(Action execute) => _execute = execute;
        public event EventHandler? CanExecuteChanged;
        public bool CanExecute(object? parameter) => true;
        public void Execute(object? parameter) => _execute();
    }
}
