namespace Chronicae.Server.Windows.Models;

public class Project
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public int NoteCount { get; set; }
    public VectorStatus VectorStatus { get; set; } = new();
}
