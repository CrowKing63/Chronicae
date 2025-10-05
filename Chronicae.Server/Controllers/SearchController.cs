using Microsoft.AspNetCore.Mvc;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;
using Chronicae.Server.Models;

namespace Chronicae.Server.Controllers
{
    [ApiController]
    [Route("api/search")]
    public class SearchController : ControllerBase
    {
        private readonly INoteRepository _noteRepository;
        private readonly ILogger<SearchController> _logger;

        public SearchController(
            INoteRepository noteRepository,
            ILogger<SearchController> logger)
        {
            _noteRepository = noteRepository;
            _logger = logger;
        }

        /// <summary>
        /// Searches notes across projects or within a specific project
        /// </summary>
        /// <param name="query">Search query</param>
        /// <param name="projectId">Project ID to search within (optional)</param>
        /// <param name="mode">Search mode (keyword or semantic)</param>
        /// <param name="limit">Maximum number of results</param>
        /// <returns>Search results with relevance scores</returns>
        [HttpGet]
        public async Task<ActionResult<SearchResponse>> Search(
            [FromQuery] string query,
            [FromQuery] Guid? projectId = null,
            [FromQuery] SearchMode mode = SearchMode.Keyword,
            [FromQuery] int limit = 50)
        {
            try
            {
                // Validate query
                if (string.IsNullOrWhiteSpace(query))
                {
                    return BadRequest(new { code = "invalid_request", message = "Search query is required" });
                }

                // Validate limit
                if (limit <= 0 || limit > 100)
                {
                    return BadRequest(new { code = "invalid_request", message = "Limit must be between 1 and 100" });
                }

                // Validate search mode
                if (!Enum.IsDefined(typeof(SearchMode), mode))
                {
                    return BadRequest(new { code = "invalid_request", message = "Invalid search mode" });
                }

                _logger.LogInformation("Performing search with query: '{Query}', mode: {Mode}, projectId: {ProjectId}, limit: {Limit}", 
                    query, mode, projectId, limit);

                var searchResults = await _noteRepository.SearchAsync(projectId, query.Trim(), mode, limit);
                var resultsList = searchResults.ToList();

                return Ok(new SearchResponse 
                { 
                    Items = resultsList,
                    Query = query.Trim(),
                    Mode = mode,
                    ProjectId = projectId,
                    TotalResults = resultsList.Count
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error performing search with query: '{Query}'", query);
                return StatusCode(500, new { code = "internal_error", message = "Failed to perform search" });
            }
        }

        /// <summary>
        /// Gets search suggestions based on partial query
        /// </summary>
        /// <param name="query">Partial search query</param>
        /// <param name="projectId">Project ID to search within (optional)</param>
        /// <param name="limit">Maximum number of suggestions</param>
        /// <returns>Search suggestions</returns>
        [HttpGet("suggestions")]
        public async Task<ActionResult<IEnumerable<string>>> GetSearchSuggestions(
            [FromQuery] string query,
            [FromQuery] Guid? projectId = null,
            [FromQuery] int limit = 10)
        {
            try
            {
                // Validate query
                if (string.IsNullOrWhiteSpace(query) || query.Length < 2)
                {
                    return BadRequest(new { code = "invalid_request", message = "Query must be at least 2 characters long" });
                }

                // Validate limit
                if (limit <= 0 || limit > 20)
                {
                    return BadRequest(new { code = "invalid_request", message = "Limit must be between 1 and 20" });
                }

                // For now, perform a simple search and extract titles as suggestions
                // TODO: Implement proper suggestion logic when needed
                var searchResults = await _noteRepository.SearchAsync(projectId, query.Trim(), SearchMode.Keyword, limit);
                var suggestions = searchResults
                    .Select(r => r.Title)
                    .Where(title => title.Contains(query, StringComparison.OrdinalIgnoreCase))
                    .Distinct()
                    .Take(limit)
                    .ToList();

                return Ok(suggestions);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting search suggestions for query: '{Query}'", query);
                return StatusCode(500, new { code = "internal_error", message = "Failed to get search suggestions" });
            }
        }
    }
}