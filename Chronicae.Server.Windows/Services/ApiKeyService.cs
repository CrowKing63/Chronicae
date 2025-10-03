using Chronicae.Server.Windows.Models;

namespace Chronicae.Server.Windows.Services;

public class ApiKeyService
{
    private readonly List<ApiKey> _apiKeys;

    public ApiKeyService()
    {
        // In a real application, this would come from a database or configuration
        _apiKeys = new List<ApiKey>();
        
        // Add a default API key for development
        _apiKeys.Add(new ApiKey
        {
            Key = GenerateSecureApiKey(),
            Name = "Development Key",
            Permissions = "read,write,admin",
            CreatedAt = DateTimeOffset.UtcNow,
            IsActive = true
        });
    }

    public string GenerateApiKey(string name, string permissions = "read,write")
    {
        var apiKey = new ApiKey
        {
            Key = GenerateSecureApiKey(),
            Name = name,
            Permissions = permissions,
            CreatedAt = DateTimeOffset.UtcNow,
            IsActive = true
        };

        _apiKeys.Add(apiKey);
        return apiKey.Key;
    }

    public ApiKey? ValidateApiKey(string apiKey)
    {
        return _apiKeys.FirstOrDefault(k => k.Key == apiKey && k.IsActive);
    }

    public bool HasPermission(ApiKey apiKey, string permission)
    {
        var permissions = apiKey.Permissions.Split(',');
        return permissions.Contains(permission, StringComparer.OrdinalIgnoreCase);
    }

    private string GenerateSecureApiKey()
    {
        // In a real application, use a more secure method to generate API keys
        // This is a simple implementation for demonstration purposes
        var randomBytes = new byte[32];
        using (var rng = System.Security.Cryptography.RandomNumberGenerator.Create())
        {
            rng.GetBytes(randomBytes);
        }
        return Convert.ToBase64String(randomBytes).Replace("+", "").Replace("/", "").Replace("=", "");
    }
}