namespace Chronicae.Server.Windows.Models;

public class ApiKey
{
    public string Key { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Permissions { get; set; } = "read,write"; // read, write, admin 등의 권한
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
    public bool IsActive { get; set; } = true;
}