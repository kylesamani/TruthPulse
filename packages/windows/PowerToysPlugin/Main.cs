using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Wox.Plugin;

namespace Community.PowerToys.Run.Plugin.TruthPulse;

public class Main : IPlugin
{
    public static string PluginID => "B8F3E2A1D4C74F9E8A1B3C5D7E9F0A2B";

    public string Name => "TruthPulse";

    public string Description => "Search Kalshi prediction markets with live odds";

    private string _iconPath = "Images/dark.png";
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(5) };

    private const int BasePort = 47392;
    private const int MaxPort = 47401;

    public void Init(PluginInitContext context)
    {
        try
        {
            _iconPath = context.CurrentPluginMetadata.IcoPathDark ?? "Images/dark.png";
        }
        catch
        {
            _iconPath = "Images/dark.png";
        }
    }

    public List<Result> Query(Query query)
    {
        var search = query.Search?.Trim();
        var displayText = query.Search;
        if (string.IsNullOrEmpty(search) || search.Length < 3)
        {
            return new List<Result>
            {
                new Result
                {
                    Title = "Search Kalshi prediction markets",
                    SubTitle = "Type at least 3 characters to search",
                    IcoPath = _iconPath,
                    Score = 0,
                    QueryTextDisplay = displayText,
                }
            };
        }

        try
        {
            var encoded = Uri.EscapeDataString(search);
            string? json = null;

            for (int port = BasePort; port <= MaxPort; port++)
            {
                try
                {
                    var url = $"http://127.0.0.1:{port}/search?q={encoded}";
                    var response = _http.GetAsync(url).GetAwaiter().GetResult();
                    if (response.IsSuccessStatusCode)
                    {
                        json = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
                        break;
                    }
                }
                catch (HttpRequestException) { continue; }
                catch (TaskCanceledException) { continue; }
            }

            if (json == null)
            {
                return new List<Result>
                {
                    new Result
                    {
                        Title = "TruthPulse is not running",
                        SubTitle = "Start the TruthPulse app to search prediction markets",
                        IcoPath = _iconPath,
                        Score = 0,
                        QueryTextDisplay = displayText,
                    }
                };
            }

            var items = JsonSerializer.Deserialize<SearchProviderResult[]>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (items == null || items.Length == 0)
            {
                return new List<Result>
                {
                    new Result
                    {
                        Title = "No markets found",
                        SubTitle = $"No Kalshi markets matching \"{search}\"",
                        IcoPath = _iconPath,
                        Score = 0,
                        QueryTextDisplay = displayText,
                    }
                };
            }

            var results = new List<Result>(items.Length);
            for (int i = 0; i < items.Length; i++)
            {
                var item = items[i];
                var marketUrl = item.Url;
                results.Add(new Result
                {
                    Title = item.Title,
                    SubTitle = item.Description,
                    IcoPath = _iconPath,
                    Score = 100 - i,
                    QueryTextDisplay = displayText,
                    Action = _ =>
                    {
                        try
                        {
                            Process.Start(new ProcessStartInfo(marketUrl) { UseShellExecute = true });
                        }
                        catch { }
                        return true;
                    },
                });
            }

            return results;
        }
        catch (Exception ex)
        {
            return new List<Result>
            {
                new Result
                {
                    Title = "TruthPulse error",
                    SubTitle = ex.Message,
                    IcoPath = _iconPath,
                    Score = 0,
                    QueryTextDisplay = displayText,
                }
            };
        }
    }

    private sealed class SearchProviderResult
    {
        public string Title { get; set; } = "";
        public string Description { get; set; } = "";
        public string Url { get; set; } = "";
        public string Icon { get; set; } = "";
    }
}
