using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace TruthPulse.Services;

/// <summary>
/// Loads synonyms from the shared synonyms.json and expands query tokens at search time.
/// </summary>
public sealed class SynonymTable
{
    private readonly Dictionary<string, List<string>> _table;

    public SynonymTable()
    {
        _table = Load();
    }

    /// <summary>
    /// Expand a list of query tokens using synonyms.
    /// Returns the original tokens plus any expanded terms.
    /// </summary>
    public List<string> ExpandTokens(List<string> tokens)
    {
        var expanded = new List<string>(tokens);
        foreach (var token in tokens)
        {
            if (_table.TryGetValue(token, out var synonyms))
            {
                foreach (var synonym in synonyms)
                {
                    var synonymTokens = RankingPolicy.SearchTokens(
                        RankingPolicy.NormalizeSearchText(synonym));
                    foreach (var st in synonymTokens)
                    {
                        if (!expanded.Contains(st))
                            expanded.Add(st);
                    }
                }
            }
        }
        return expanded;
    }

    private static Dictionary<string, List<string>> Load()
    {
        var path = FindSynonymsFile();
        if (path == null)
            return new Dictionary<string, List<string>>();

        try
        {
            var json = File.ReadAllText(path);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!root.TryGetProperty("synonyms", out var synonymsEl))
                return new Dictionary<string, List<string>>();

            var result = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var prop in synonymsEl.EnumerateObject())
            {
                var values = new List<string>();
                foreach (var val in prop.Value.EnumerateArray())
                {
                    var s = val.GetString();
                    if (!string.IsNullOrEmpty(s))
                        values.Add(s);
                }
                result[prop.Name.ToLowerInvariant()] = values;
            }
            return result;
        }
        catch
        {
            return new Dictionary<string, List<string>>();
        }
    }

    private static string? FindSynonymsFile()
    {
        // Look relative to the executable for packages/shared/synonyms.json
        var exeDir = AppContext.BaseDirectory;
        var dir = exeDir;
        for (var i = 0; i < 6; i++)
        {
            var candidate = Path.Combine(dir, "packages", "shared", "synonyms.json");
            if (File.Exists(candidate))
                return candidate;
            var parent = Directory.GetParent(dir);
            if (parent == null) break;
            dir = parent.FullName;
        }

        // Also check next to the executable
        var local = Path.Combine(exeDir, "synonyms.json");
        if (File.Exists(local))
            return local;

        return null;
    }
}
