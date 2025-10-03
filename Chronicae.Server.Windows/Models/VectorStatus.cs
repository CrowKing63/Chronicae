namespace Chronicae.Server.Windows.Models;

public class VectorStatus
{
    public DateTimeOffset LastIndexedAt { get; set; }
    public int PendingJobs { get; set; }

    public VectorStatus() { }
}
