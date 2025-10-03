using System.Net.Http.Json;
using Chronicae.Windows.Models;

namespace Chronicae.Windows.Services;

public class ApiClient
{
    private readonly HttpClient _httpClient;

    public ApiClient()
    {
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri("http://localhost:5000/api/") // Assuming server runs on this port
        };
    }

    public async Task<List<Project>?> GetProjectsAsync()
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<List<Project>>("projects");
        }
        catch (HttpRequestException ex)
        {
            Console.WriteLine($"Error getting projects: {ex.Message}");
            return null;
        }
    }

    public async Task<List<Note>?> GetNotesAsync(string projectId)
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<List<Note>>($"projects/{projectId}/notes");
        }
        catch (HttpRequestException ex)
        {
            Console.WriteLine($"Error getting notes for project {projectId}: {ex.Message}");
            return null;
        }
    }

    public async Task<SystemStatus?> GetSystemStatusAsync()
    {
        try
        {
            return await _httpClient.GetFromJsonAsync<SystemStatus>("status");
        }
        catch (HttpRequestException ex)
        {
            Console.WriteLine($"Error getting system status: {ex.Message}");
            return null;
        }
    }
}
