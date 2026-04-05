using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using TruthPulse.Models;

namespace TruthPulse.Services;

public sealed class MarketCacheStore
{
    private readonly string _cachePath;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public MarketCacheStore()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var dir = Path.Combine(appData, "TruthPulse");
        Directory.CreateDirectory(dir);
        _cachePath = Path.Combine(dir, "cache.json");
    }

    public bool Exists() => File.Exists(_cachePath);

    public async Task<DateTime?> SavedAtAsync()
    {
        if (!File.Exists(_cachePath))
            return null;

        try
        {
            var json = await File.ReadAllTextAsync(_cachePath);
            var payload = JsonSerializer.Deserialize<CachePayload>(json, JsonOptions);
            return payload?.SavedAt;
        }
        catch
        {
            return null;
        }
    }

    public async Task<List<MarketSummary>> LoadAsync()
    {
        if (!File.Exists(_cachePath))
            return new List<MarketSummary>();

        try
        {
            var json = await File.ReadAllTextAsync(_cachePath);
            var payload = JsonSerializer.Deserialize<CachePayload>(json, JsonOptions);
            if (payload?.Markets == null)
                return new List<MarketSummary>();

            return payload.Markets.FindAll(m =>
            {
                var status = m.Status.ToLowerInvariant();
                return status == "active" || status == "open";
            });
        }
        catch
        {
            return new List<MarketSummary>();
        }
    }

    public async Task SaveAsync(List<MarketSummary> markets)
    {
        var payload = new CachePayload
        {
            SavedAt = DateTime.UtcNow,
            Markets = markets
        };

        try
        {
            var json = JsonSerializer.Serialize(payload, JsonOptions);
            var dir = Path.GetDirectoryName(_cachePath);
            if (dir != null)
                Directory.CreateDirectory(dir);
            await File.WriteAllTextAsync(_cachePath, json);
        }
        catch
        {
            // Silently fail on write errors — cache is non-critical
        }
    }

    private sealed class CachePayload
    {
        public DateTime SavedAt { get; set; }
        public List<MarketSummary> Markets { get; set; } = new();
    }
}
