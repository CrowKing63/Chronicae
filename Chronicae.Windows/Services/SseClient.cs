
using System.Text.Json;
using Chronicae.Windows.Models;

namespace Chronicae.Windows.Services;

public class SseClient
{
    private readonly HttpClient _httpClient;
    private CancellationTokenSource? _cts;

    public event Action<SseEvent>? OnEventReceived;

    public SseClient()
    {
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri("http://localhost:5000/") // Base address for SSE endpoint
        };
    }

    public async Task StartListeningAsync()
    {
        _cts = new CancellationTokenSource();
        try
        {
            var request = new HttpRequestMessage(HttpMethod.Get, "api/events");
            var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, _cts.Token);
            response.EnsureSuccessStatusCode();

            using var stream = await response.Content.ReadAsStreamAsync();
            using var reader = new StreamReader(stream);

            while (!_cts.Token.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync();
                if (string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }

                if (line.StartsWith("event: "))
                {
                    var eventName = line.Substring("event: ".Length);
                    var dataLine = await reader.ReadLineAsync(); // Expect data line next
                    if (dataLine != null && dataLine.StartsWith("data: "))
                    {
                        var jsonData = dataLine.Substring("data: ".Length);
                        var sseEvent = new SseEvent { Event = eventName, Data = JsonSerializer.Deserialize<JsonElement>(jsonData) };
                        OnEventReceived?.Invoke(sseEvent);
                    }
                }
            }
        }
        catch (HttpRequestException ex)
        {
            Console.WriteLine($"SSE connection error: {ex.Message}");
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("SSE listening cancelled.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"An unexpected error occurred in SSE client: {ex.Message}");
        }
    }

    public void StopListening()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;
    }
}
