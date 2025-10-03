using Chronicae.Server.Windows.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Primitives;

namespace Chronicae.Server.Windows.Middlewares;

public class ApiKeyMiddleware
{
    private readonly RequestDelegate _next;
    private const string APIKEY_HEADER = "X-API-Key";

    public ApiKeyMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, ApiKeyService apiKeyService)
    {
        // Check for API key in header
        if (context.Request.Headers.TryGetValue(APIKEY_HEADER, out StringValues values))
        {
            var apiKey = values.FirstOrDefault();
            if (!string.IsNullOrEmpty(apiKey))
            {
                var keyInfo = apiKeyService.ValidateApiKey(apiKey);
                if (keyInfo != null && keyInfo.IsActive)
                {
                    // Add API key info to request context for later use
                    context.Items["ApiKey"] = keyInfo;
                }
                // If API key is invalid, we continue without authentication
                // This allows endpoints that don't require API key to still work
            }
        }

        await _next(context);
    }
}