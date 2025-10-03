namespace Chronicae.Server.Windows.Models;

public class SseEvent
{
    public string Event { get; set; } = string.Empty;
    public object Data { get; set; } = new();
}
