using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;

namespace TruthPulse.Services;

internal sealed class AutoUpdater
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
