namespace Chronicae.Server.Windows.Models;

public class AiQueryRequest
{
    public string Query { get; set; } = string.Empty;
    public string? Context { get; set; }
    public Dictionary<string, object>? Parameters { get; set; }
}