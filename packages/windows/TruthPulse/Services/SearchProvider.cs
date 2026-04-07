using System;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using TruthPulse.Services;

namespace TruthPulse.Services;

/// <summary>
/// Localhost HTTP server that exposes TruthPulse search results to Windows Search
/// and other local consumers via GET /search?q={query}.
///
/// Binds to 127.0.0.1 only (never 0.0.0.0). Tries port 47392 first, then
/// increments until a free port is found (up to 10 attempts).
/// </summary>
public sealed class SearchProvider : IDisposable
{
    private readonly SearchService _searchService;
    private HttpListener? _listener;
    private CancellationTokenSource? _cts;
    private Task? _loopTask;

    public int Port { get; private set; }

    public SearchProvider(SearchService searchService)
    {
        _searchService = searchService;
    }

    // ── Lifecycle ──────────────────────────────────────────────────────────

    public void Start()
    {
        const int basePort = 47392;
        const int maxAttempts = 10;

        for (int attempt = 0; attempt < maxAttempts; attempt++)
        {
            int port = basePort + attempt;
            var listener = new HttpListener();
            listener.Prefixes.Add($"http://127.0.0.1:{port}/");

            try
            {
                listener.Start();
                Port = port;
                _listener = listener;
                break;
            }
            catch (HttpListenerException)
            {
                listener.Close();
                if (attempt == maxAttempts - 1)
                {
                    System.Diagnostics.Debug.WriteLine(
                        $"[SearchProvider] Could not bind on ports {basePort}–{basePort + maxAttempts - 1}; provider disabled.");
                    return;
                }
            }
        }

        _cts = new CancellationTokenSource();
        _loopTask = Task.Run(() => AcceptLoopAsync(_cts.Token));

        System.Diagnostics.Debug.WriteLine($"[SearchProvider] Listening on http://127.0.0.1:{Port}/");
    }

    public void Stop()
    {
        _cts?.Cancel();

        try { _listener?.Stop(); } catch { }

        try { _loopTask?.Wait(TimeSpan.FromSeconds(3)); } catch { }

        _listener = null;
    }

    public void Dispose() => Stop();

    // ── Accept loop ────────────────────────────────────────────────────────

    private async Task AcceptLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested && _listener is { IsListening: true })
        {
            HttpListenerContext ctx;
            try
            {
                ctx = await _listener.GetContextAsync();
            }
            catch (HttpListenerException)
            {
                break; // listener was stopped
            }
            catch (ObjectDisposedException)
            {
                break;
            }

            // Handle each request on its own thread-pool task so the loop
            // is never blocked by a slow handler.
            _ = Task.Run(() => HandleRequestAsync(ctx, ct), ct);
        }
    }

    // ── Request handler ────────────────────────────────────────────────────

    private async Task HandleRequestAsync(HttpListenerContext ctx, CancellationToken ct)
    {
        var req = ctx.Request;
        var resp = ctx.Response;

        try
        {
            // Only handle GET /search
            if (req.HttpMethod != "GET" ||
                !string.Equals(req.Url?.AbsolutePath, "/search", StringComparison.OrdinalIgnoreCase))
            {
                resp.StatusCode = 404;
                resp.Close();
                return;
            }

            // CORS header so browser extensions / local web pages can query us
            resp.AddHeader("Access-Control-Allow-Origin", "*");
            resp.ContentType = "application/json; charset=utf-8";

            var query = req.QueryString["q"] ?? "";
            var results = await SearchAsync(query, ct);

            var json = JsonSerializer.Serialize(results, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

            var bytes = Encoding.UTF8.GetBytes(json);
            resp.ContentLength64 = bytes.Length;
            await resp.OutputStream.WriteAsync(bytes, ct);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[SearchProvider] Handler error: {ex.Message}");
            try
            {
                resp.StatusCode = 500;
            }
            catch { }
        }
        finally
        {
            try { resp.Close(); } catch { }
        }
    }

    // ── Search helper ──────────────────────────────────────────────────────

    private Task<SearchProviderResult[]> SearchAsync(string query, CancellationToken _)
    {
        try
        {
            var results = _searchService.Search(query, limit: 10);
            var items = new SearchProviderResult[results.Count];

            for (int i = 0; i < results.Count; i++)
            {
                var r = results[i];
                var market = r.Market;

                var odds = r.EmphasizedOdds;
                var oddsText = odds.HasValue ? $"{odds}% YES" : "N/A";
                var closeText = market.CloseTime.HasValue
                    ? $"closes {market.CloseTime.Value:MMM d, yyyy}"
                    : "open";

                items[i] = new SearchProviderResult(
                    Title: market.Title,
                    Description: $"{oddsText} — {closeText}",
                    Url: market.ResolvedWebUrl(),
                    Icon: "truthpulse"
                );
            }

            return Task.FromResult(items);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[SearchProvider] Search error: {ex.Message}");
            return Task.FromResult(Array.Empty<SearchProviderResult>());
        }
    }

    // ── Result DTO ─────────────────────────────────────────────────────────

    private sealed record SearchProviderResult(
        string Title,
        string Description,
        string Url,
        string Icon);
}
