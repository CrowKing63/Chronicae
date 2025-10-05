using System.Text.Json;
using Chronicae.Core.Models;
using Chronicae.Core.Utilities;
using Microsoft.Extensions.Logging;

namespace Chronicae.Core.Services;

/// <summary>
/// Service for managing server configuration settings
/// </summary>
public class ServerConfigurationService
{
    private readonly string _configPath;
    private readonly ILogger<ServerConfigurationService>? _logger;
    private ServerConfiguration _config;
    private readonly object _lock = new object();

    /// <summary>
    /// Gets the current server port
    /// </summary>
    public int Port => _config.Port;

    /// <summary>
    /// Gets whether external connections are allowed
    /// </summary>
    public bool AllowExternal => _config.AllowExternal;

    /// <summary>
    /// Gets the active project ID
    /// </summary>
    public Guid? ActiveProjectId => _config.ProjectId;

    /// <summary>
    /// Gets the current authentication token
    /// </summary>
    public string? AuthToken => _config.AuthToken;

    /// <summary>
    /// Event raised when configuration changes
    /// </summary>
    public event EventHandler<ServerConfiguration>? ConfigurationChanged;

    /// <summary>
    /// Initializes a new instance of ServerConfigurationService
    /// </summary>
    /// <param name="logger">Optional logger instance</param>
    public ServerConfigurationService(ILogger<ServerConfigurationService>? logger = null)
    {
        _logger = logger;
        
        // Set config path to %APPDATA%/Chronicae/config.json
        var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var chronicaeDir = Path.Combine(appDataPath, "Chronicae");
        _configPath = Path.Combine(chronicaeDir, "config.json");
        
        // Initialize with default configuration
        _config = new ServerConfiguration();
        
        _logger?.LogInformation("ServerConfigurationService initialized with config path: {ConfigPath}", _configPath);
    }

    /// <summary>
    /// Loads configuration from file asynchronously
    /// </summary>
    public async Task LoadAsync()
    {
        try
        {
            lock (_lock)
            {
                // Ensure directory exists
                var directory = Path.GetDirectoryName(_configPath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                    _logger?.LogInformation("Created configuration directory: {Directory}", directory);
                }
            }

            if (File.Exists(_configPath))
            {
                var json = await File.ReadAllTextAsync(_configPath);
                var loadedConfig = JsonSerializer.Deserialize<ServerConfiguration>(json);
                
                if (loadedConfig != null)
                {
                    lock (_lock)
                    {
                        _config = loadedConfig;
                    }
                    _logger?.LogInformation("Configuration loaded successfully from {ConfigPath}", _configPath);
                }
                else
                {
                    _logger?.LogWarning("Failed to deserialize configuration, using defaults");
                }
            }
            else
            {
                _logger?.LogInformation("Configuration file not found, using defaults");
                // Save default configuration
                await SaveAsync();
            }
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to load configuration from {ConfigPath}", _configPath);
            // Continue with default configuration
        }
    }

    /// <summary>
    /// Saves current configuration to file asynchronously
    /// </summary>
    public async Task SaveAsync()
    {
        try
        {
            ServerConfiguration configToSave;
            lock (_lock)
            {
                configToSave = _config.Clone();
            }

            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };

            var json = JsonSerializer.Serialize(configToSave, options);
            
            // Ensure directory exists
            var directory = Path.GetDirectoryName(_configPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            await File.WriteAllTextAsync(_configPath, json);
            _logger?.LogInformation("Configuration saved successfully to {ConfigPath}", _configPath);
            
            // Raise configuration changed event
            ConfigurationChanged?.Invoke(this, configToSave);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to save configuration to {ConfigPath}", _configPath);
            throw;
        }
    }

    /// <summary>
    /// Updates the server port and saves configuration
    /// </summary>
    /// <param name="port">New port number</param>
    public async Task UpdatePortAsync(int port)
    {
        if (port < 1 || port > 65535)
        {
            throw new ArgumentOutOfRangeException(nameof(port), "Port must be between 1 and 65535");
        }

        lock (_lock)
        {
            _config.Port = port;
        }

        await SaveAsync();
        _logger?.LogInformation("Server port updated to {Port}", port);
    }

    /// <summary>
    /// Updates the allow external connections setting and saves configuration
    /// </summary>
    /// <param name="allow">Whether to allow external connections</param>
    public async Task UpdateAllowExternalAsync(bool allow)
    {
        lock (_lock)
        {
            _config.AllowExternal = allow;
        }

        await SaveAsync();
        _logger?.LogInformation("Allow external connections updated to {AllowExternal}", allow);
    }

    /// <summary>
    /// Generates a new authentication token and saves configuration
    /// </summary>
    public async Task GenerateTokenAsync()
    {
        var newToken = SecureTokenGenerator.GenerateToken();
        
        lock (_lock)
        {
            _config.AuthToken = newToken;
        }

        await SaveAsync();
        _logger?.LogInformation("New authentication token generated");
    }

    /// <summary>
    /// Revokes the current authentication token and saves configuration
    /// </summary>
    public async Task RevokeTokenAsync()
    {
        lock (_lock)
        {
            _config.AuthToken = null;
        }

        await SaveAsync();
        _logger?.LogInformation("Authentication token revoked");
    }

    /// <summary>
    /// Sets the active project ID and saves configuration
    /// </summary>
    /// <param name="projectId">Project ID to set as active, or null to clear</param>
    public async Task SetActiveProjectAsync(Guid? projectId)
    {
        lock (_lock)
        {
            _config.ProjectId = projectId;
        }

        await SaveAsync();
        _logger?.LogInformation("Active project updated to {ProjectId}", projectId);
    }

    /// <summary>
    /// Gets a copy of the current configuration
    /// </summary>
    /// <returns>Copy of current configuration</returns>
    public ServerConfiguration GetConfiguration()
    {
        lock (_lock)
        {
            return _config.Clone();
        }
    }

    /// <summary>
    /// Checks if authentication is enabled (token exists)
    /// </summary>
    /// <returns>True if authentication token is set</returns>
    public bool IsAuthenticationEnabled()
    {
        lock (_lock)
        {
            return !string.IsNullOrEmpty(_config.AuthToken);
        }
    }

    /// <summary>
    /// Validates if the provided token matches the stored token
    /// </summary>
    /// <param name="token">Token to validate</param>
    /// <returns>True if token is valid</returns>
    public bool ValidateToken(string? token)
    {
        if (string.IsNullOrEmpty(token))
            return false;

        lock (_lock)
        {
            return !string.IsNullOrEmpty(_config.AuthToken) && _config.AuthToken == token;
        }
    }
}