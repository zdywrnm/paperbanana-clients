using System.Text.Json;

namespace PaperBanana.WinUI;

public static class ModelCatalogLoader
{
    public static ModelCatalog Load()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Assets", "model-catalog.json");
        if (!File.Exists(path))
        {
            path = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "Assets", "model-catalog.json");
        }

        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var root = document.RootElement;
        var providerMap = root.GetProperty("providers");
        var providers = new List<ProviderOption>();

        foreach (var id in root.GetProperty("providerOrder").EnumerateArray().Select(item => item.GetString()).Where(id => !string.IsNullOrWhiteSpace(id)))
        {
            var provider = providerMap.GetProperty(id!);
            providers.Add(new ProviderOption
            {
                Id = id!,
                Label = ReadString(provider, "label"),
                KeyName = ReadString(provider, "keyName"),
                KeyPlaceholder = ReadString(provider, "keyPlaceholder"),
                MainModel = ReadString(provider, "mainModel"),
                ImageModel = ReadString(provider, "imageModel"),
                MainModels = ReadModelOptions(provider.GetProperty("mainModels")),
                ImageModels = ReadModelOptions(provider.GetProperty("imageModels")),
                GuideUrl = ReadString(provider, "guideUrl"),
                GuideSteps = provider.GetProperty("guideSteps").EnumerateArray().Select(item => item.GetString() ?? "").Where(item => item.Length > 0).ToArray()
            });
        }

        return new ModelCatalog
        {
            Providers = providers,
            InfographicCategories = ReadCatalogOptions(root.GetProperty("infographicCategories"), hasDescription: true),
            QuickStartExamples = ReadExamples(root.GetProperty("quickStartExamples")),
            PipelineOptions = ReadCatalogOptions(root.GetProperty("pipelineOptions")),
            RetrievalOptions = ReadCatalogOptions(root.GetProperty("retrievalOptions")),
            AspectRatioOptions = ReadCatalogOptions(root.GetProperty("aspectRatioOptions")),
            CandidateOptions = ReadCatalogOptions(root.GetProperty("candidateOptions")),
            CriticRoundOptions = ReadCatalogOptions(root.GetProperty("criticRoundOptions")),
            StatusLabels = root.GetProperty("statusLabels").EnumerateObject().ToDictionary(item => item.Name, item => item.Value.GetString() ?? item.Name),
            SampleMethod = ReadString(root, "sampleMethod")
        };
    }

    private static IReadOnlyList<ModelOption> ReadModelOptions(JsonElement array)
    {
        return array.EnumerateArray()
            .Select(item => new ModelOption(
                item[0].GetString() ?? "",
                item[1].GetString() ?? "",
                item.GetArrayLength() > 2 ? item[2].GetString() ?? "" : ""))
            .ToArray();
    }

    private static IReadOnlyList<CatalogOption> ReadCatalogOptions(JsonElement array, bool hasDescription = false)
    {
        return array.EnumerateArray()
            .Select(item => new CatalogOption(
                item[0].GetString() ?? "",
                item[1].GetString() ?? "",
                hasDescription && item.GetArrayLength() > 2 ? item[2].GetString() ?? "" : ""))
            .ToArray();
    }

    private static IReadOnlyList<QuickStartExample> ReadExamples(JsonElement array)
    {
        return array.EnumerateArray()
            .Select(item => new QuickStartExample(
                ReadString(item, "id"),
                ReadString(item, "label"),
                ReadString(item, "title"),
                ReadString(item, "category"),
                ReadString(item, "caption"),
                ReadString(item, "methodContent"),
                ReadString(item, "hint")))
            .ToArray();
    }

    private static string ReadString(JsonElement element, string name)
    {
        return element.TryGetProperty(name, out var value) ? value.GetString() ?? "" : "";
    }
}
