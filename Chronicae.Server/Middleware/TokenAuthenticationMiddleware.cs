using System.Text.Json;
using Chronicae.Core.Services;

namespace Chronicae.Server.Middleware;

public class TokenAuthenticationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<TokenAuthenticationMiddleware> _logger;

    public TokenAuthenticationMiddleware(RequestDelegate next, ILogger<TokenAuthenticationMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, ServerConfigurationService configService)
    {
        // Allow CORS preflight requests
        if (context.Request.Method == "OPTIONS")
        {
            await _next(context);
            return;
        }
        
        var path = context.Request.Path.Value?.ToLowerInvariant();
        
        if (RequiresAuthentication(path))
        {
            var token = configService.AuthToken;
            
            // If no token is configured, allow access
            if (!string.IsNullOrEmpty(token))
            {
                var authHeader = context.Request.Headers["Authorization"].FirstOrDefault();
                
                if (authHeader == null || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogWarning("Authentication required but no Bearer token provided for path: {Path}", path);
                    context.Response.StatusCode = 401;
                    context.Response.Headers["WWW-Authenticate"] = "Bearer";
                    context.Response.ContentType = "application/json";
                    
                    var errorResponse = new
                    {
                        code = "unauthorized",
                        message = "Authentication required"
                    };
                    
                    await context.Response.WriteAsync(JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
                    {
                        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                    }));
                    return;
                }
                
                var providedToken = authHeader.Substring("Bearer ".Length).Trim();
                
                if (providedToken != token)
                {
                    _logger.LogWarning("Invalid token provided for path: {Path}", path);
                    context.Response.StatusCode = 401;
                    context.Response.ContentType = "application/json";
                    
                    var errorResponse = new
                    {
                        code = "unauthorized",
                        message = "Invalid token"
                    };
                    
                    await context.Response.WriteAsync(JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
                    {
                        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                    }));
                    return;
                }
                
                _logger.LogDebug("Authentication successful for path: {Path}", path);
            }
        }
        
        await _next(context);
    }
    
    private static bool RequiresAuthentication(string? path)
    {
        if (string.IsNullOrEmpty(path))
            return false;
            
        return path.StartsWith("/api") || path == "/api/events";
    }
}