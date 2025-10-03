using System.Collections.Concurrent;
using System.Text.Json;
using Chronicae.Server.Windows.Models;
using Microsoft.Extensions.Caching.Memory;

namespace Chronicae.Server.Windows.Services;

public class SseService
{
    private readonly ConcurrentBag<StreamWriter> _clients = new();
    private readonly IMemoryCache? _cache;

    public SseService(IMemoryCache? cache = null)
    {
        _cache = cache;
    }

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
        // 캐시 무효화 로직
        if (_cache != null)
        {
            // 프로젝트 관련 이벤트일 경우 프로젝트 캐시를 삭제
            if (sseEvent.Event.Contains("project"))
            {
                _cache.Remove("projects_list");
            }
            // 노트 관련 이벤트일 경우 해당 프로젝트의 노트 캐시를 삭제
            else if (sseEvent.Event.Contains("note") && sseEvent.Data is Note note)
            {
                _cache.Remove($"notes_list_{note.ProjectId}");
            }
        }

        var message = $"event: {sseEvent.Event}\\ndata: {JsonSerializer.Serialize(sseEvent.Data)}\\n\\n";

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