namespace Chronicae.Server.Windows.Models;

public class SystemStatus
{
    public long Uptime { get; set; }
    public string? CurrentProjectId { get; set; }
    public int Projects { get; set; }
    public int NotesIndexed { get; set; }
    public int VersionsStored { get; set; }

    public SystemStatus(long uptime, string? currentProjectId, int projects, int notesIndexed, int versionsStored)
    {
        Uptime = uptime;
        CurrentProjectId = currentProjectId;
        Projects = projects;
        NotesIndexed = notesIndexed;
        VersionsStored = versionsStored;
    }
}