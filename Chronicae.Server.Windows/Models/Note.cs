namespace Chronicae.Server.Windows.Models;

public class Note
{
    public string Id { get; set; } = string.Empty;
    public string ProjectId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public List<string> Tags { get; set; } = new();
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string Excerpt { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty; // Added Content property
    public int Version { get; set; }
}