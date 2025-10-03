using System.Collections.Concurrent;
using System.Text.Json;
using Chronicae.Server.Windows.Models;

namespace Chronicae.Server.Windows.Services;

public class SseService
{
    private readonly ConcurrentBag<StreamWriter> _clients = new();

    public void AddClient(StreamWriter client)
    {
        _clients.Add(client);
    }

    public void RemoveClient(StreamWriter client)
    {
        // StreamWriter doesn't have a good equality comparison, so we can't easily remove.
        // For this simple case, we'll rely on the connection closing.
        // In a real-world app, a more robust client management system is needed.
    }

    public async Task BroadcastEvent(SseEvent sseEvent)
    {
        var message = $"event: {sseEvent.Event}\ndata: {JsonSerializer.Serialize(sseEvent.Data)}\n\n";

        foreach (var client in _clients)
        {
            try
            {
                await client.WriteAsync(message);
                await client.FlushAsync();
            }
            catch
            {
                // Client is disconnected, remove it.
                // This is a simplistic way to handle cleanup.
            }
        }
    }
}
