namespace Chronicae.Server.Windows.Models;

public class AiQueryResponse
{
    public string Query { get; set; } = string.Empty;
    public string Response { get; set; } = string.Empty;
    public DateTimeOffset Timestamp { get; set; }
    public Dictionary<string, object>? Metadata { get; set; }
}