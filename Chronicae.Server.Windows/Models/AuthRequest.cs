namespace Chronicae.Server.Windows.Models;

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class GenerateApiKeyRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Permissions { get; set; }
}