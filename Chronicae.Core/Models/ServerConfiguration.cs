using System.Text.Json.Serialization;

namespace Chronicae.Core.Models;

/// <summary>
/// Server configuration model for storing application settings
/// </summary>
public class ServerConfiguration
{
    /// <summary>
    /// Port number for the HTTP server (default: 8843)
    /// </summary>
    public int Port { get; set; } = 8843;

    /// <summary>
    /// Whether to allow external connections (default: true)
    /// When true, server binds to 0.0.0.0, when false binds to 127.0.0.1
    /// </summary>
    public bool AllowExternal { get; set; } = true;

    /// <summary>
    /// Currently active project ID
    /// </summary>
    public Guid? ProjectId { get; set; }

    /// <summary>
    /// Authentication token for API access
    /// </summary>
    public string? AuthToken { get; set; }

    /// <summary>
    /// Creates a new ServerConfiguration with default values
    /// </summary>
    public ServerConfiguration()
    {
    }

    /// <summary>
    /// Creates a copy of the current configuration
    /// </summary>
    public ServerConfiguration Clone()
    {
        return new ServerConfiguration
        {
            Port = Port,
            AllowExternal = AllowExternal,
            ProjectId = ProjectId,
            AuthToken = AuthToken
        };
    }
}