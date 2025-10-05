using Microsoft.AspNetCore.Mvc;
using Chronicae.Core.Interfaces;
using Chronicae.Server.Models;

namespace Chronicae.Server.Controllers
{
    [ApiController]
    [Route("api/projects/{projectId}/notes/{noteId}/versions")]
    public class VersionsController : ControllerBase
    {
        private readonly IVersionRepository _versionRepository;
        private readonly INoteRepository _noteRepository;
        private readonly IExportService _exportService;
        private readonly ILogger<VersionsController> _logger;

        public VersionsController(
            IVersionRepository versionRepository,
            INoteRepository noteRepository,
            IExportService exportService,
            ILogger<VersionsController> logger)
        {
            _versionRepository = versionRepository;
            _noteRepository = noteRepository;
            _exportService = exportService;
            _logger = logger;
        }

        /// <summary>
        /// Gets versions for a note ordered by creation date (newest first)
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="limit">Maximum number of versions to return</param>
        /// <returns>List of note versions</returns>
        [HttpGet]
        public async Task<ActionResult<VersionListResponse>> GetVersions(
            Guid projectId, 
            Guid noteId, 
            [FromQuery] int limit = 50)
        {
            try
            {
                // Validate limit
                if (limit <= 0 || limit > 100)
                {
                    return BadRequest(new { code = "invalid_request", message = "Limit must be between 1 and 100" });
                }

                // Verify note exists in the specified project
                var note = await _noteRepository.GetByIdAsync(projectId, noteId);
                if (note == null)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                var versions = await _versionRepository.GetByNoteAsync(noteId, limit);
                
                return Ok(new VersionListResponse { Items = versions });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving versions for note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve versions" });
            }
        }

        /// <summary>
        /// Gets detailed information for a specific version
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="versionId">Version ID</param>
        /// <returns>Version details with content</returns>
        [HttpGet("{versionId}")]
        public async Task<ActionResult<VersionDetailResponse>> GetVersion(
            Guid projectId, 
            Guid noteId, 
            Guid versionId)
        {
            try
            {
                // Verify note exists in the specified project
                var note = await _noteRepository.GetByIdAsync(projectId, noteId);
                if (note == null)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                var versionDetail = await _versionRepository.GetDetailAsync(noteId, versionId);
                if (versionDetail == null)
                {
                    return NotFound(new { code = "version_not_found", message = "Version not found" });
                }

                return Ok(new VersionDetailResponse 
                { 
                    Version = versionDetail.Value.Version, 
                    Content = versionDetail.Value.Content 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving version: {VersionId} for note: {NoteId} in project: {ProjectId}", 
                    versionId, noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve version" });
            }
        }

        /// <summary>
        /// Restores a note to a specific version by creating a new version with the restored content
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="versionId">Version ID to restore from</param>
        /// <returns>New version created from restoration</returns>
        [HttpPost("{versionId}/restore")]
        public async Task<ActionResult<VersionResponse>> RestoreVersion(
            Guid projectId, 
            Guid noteId, 
            Guid versionId)
        {
            try
            {
                // Verify note exists in the specified project
                var note = await _noteRepository.GetByIdAsync(projectId, noteId);
                if (note == null)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                var restoredVersion = await _versionRepository.RestoreAsync(noteId, versionId);
                if (restoredVersion == null)
                {
                    return NotFound(new { code = "version_not_found", message = "Version not found" });
                }

                return Ok(new VersionResponse { Version = restoredVersion });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error restoring version: {VersionId} for note: {NoteId} in project: {ProjectId}", 
                    versionId, noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to restore version" });
            }
        }

        /// <summary>
        /// Exports a specific version
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="versionId">Version ID</param>
        /// <param name="format">Export format (md, pdf, txt)</param>
        /// <returns>Export job information</returns>
        [HttpPost("{versionId}/export")]
        public async Task<ActionResult> ExportVersion(
            Guid projectId, 
            Guid noteId, 
            Guid versionId,
            [FromQuery] string format = "md")
        {
            try
            {
                // Validate format
                var validFormats = new[] { "md", "pdf", "txt" };
                if (!validFormats.Contains(format.ToLowerInvariant()))
                {
                    return BadRequest(new { 
                        code = "invalid_format", 
                        message = $"Invalid format. Supported formats: {string.Join(", ", validFormats)}" 
                    });
                }

                // Verify note exists in the specified project
                var note = await _noteRepository.GetByIdAsync(projectId, noteId);
                if (note == null)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                // Verify version exists
                var versionDetail = await _versionRepository.GetDetailAsync(noteId, versionId);
                if (versionDetail == null)
                {
                    return NotFound(new { code = "version_not_found", message = "Version not found" });
                }

                // Generate export file path
                var exportDir = _exportService.GetExportDirectory();
                var timestamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss");
                var fileName = $"{SanitizeFileName(versionDetail.Value.Version.Title)}_v{versionDetail.Value.Version.Version}_{timestamp}.{format.ToLowerInvariant()}";
                var outputPath = Path.Combine(exportDir, fileName);

                // Export the version
                var exportedPath = await _exportService.ExportNoteVersionAsync(versionDetail.Value.Version, format, outputPath);
                
                return Ok(new { 
                    message = "Version exported successfully",
                    filePath = exportedPath,
                    format = format,
                    fileName = Path.GetFileName(exportedPath)
                });
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Invalid export request for version: {VersionId} of note: {NoteId} in project: {ProjectId}", 
                    versionId, noteId, projectId);
                return BadRequest(new { code = "invalid_request", message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting version: {VersionId} for note: {NoteId} in project: {ProjectId}", 
                    versionId, noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to export version" });
            }
        }

        private string SanitizeFileName(string fileName)
        {
            var invalidChars = Path.GetInvalidFileNameChars();
            var sanitized = new System.Text.StringBuilder();
            
            foreach (var c in fileName)
            {
                if (invalidChars.Contains(c))
                {
                    sanitized.Append('_');
                }
                else
                {
                    sanitized.Append(c);
                }
            }
            
            return sanitized.ToString().Trim();
        }
    }
}