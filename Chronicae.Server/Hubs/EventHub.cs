using Microsoft.AspNetCore.SignalR;

namespace Chronicae.Server.Hubs;

public class EventHub : Hub
{
    private readonly ILogger<EventHub> _logger;

    public EventHub(ILogger<EventHub> logger)
    {
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);
        await Clients.Caller.SendAsync("Connected", new { message = "connected" });
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("Client disconnected: {ConnectionId}, Exception: {Exception}", 
            Context.ConnectionId, exception?.Message);
        await base.OnDisconnectedAsync(exception);
    }
}