namespace Chronicae.Server.Windows.Models;

public class VersionSnapshot
{
    public string Id { get; set; } = string.Empty;
    public string NoteId { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; }
    public int VersionNumber { get; set; }
}
