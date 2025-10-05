using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Chronicae.Server.Middleware;

public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception occurred. Path: {Path}, Method: {Method}", 
                context.Request.Path, context.Request.Method);
            await HandleExceptionAsync(context, ex);
        }
    }

    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";
        
        var (statusCode, code, message, includeDetails) = GetErrorDetails(exception);
        
        context.Response.StatusCode = (int)statusCode;
        
        var response = new
        {
            code,
            message,
            details = includeDetails ? exception.StackTrace : null
        };
        
        var jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };
        
        await context.Response.WriteAsync(JsonSerializer.Serialize(response, jsonOptions));
    }
    
    private static (HttpStatusCode StatusCode, string Code, string Message, bool IncludeDetails) GetErrorDetails(Exception exception)
    {
        return exception switch
        {
            ArgumentNullException => (HttpStatusCode.BadRequest, "invalid_argument", "Required parameter is missing", true),
            ArgumentException ex => (HttpStatusCode.BadRequest, "invalid_argument", ex.Message, true),
            UnauthorizedAccessException ex => (HttpStatusCode.Unauthorized, "unauthorized", ex.Message, true),
            KeyNotFoundException ex => (HttpStatusCode.NotFound, "not_found", ex.Message, true),
            InvalidOperationException ex => (HttpStatusCode.Conflict, "invalid_operation", ex.Message, true),
            NotSupportedException ex => (HttpStatusCode.BadRequest, "not_supported", ex.Message, true),
            TimeoutException => (HttpStatusCode.RequestTimeout, "timeout", "The request timed out", false),
            TaskCanceledException => (HttpStatusCode.RequestTimeout, "timeout", "The request was cancelled", false),
            _ => (HttpStatusCode.InternalServerError, "internal_error", "An internal server error occurred", false)
        };
    }
}