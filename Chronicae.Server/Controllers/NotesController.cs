using Microsoft.AspNetCore.Mvc;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;
using Chronicae.Server.Models;
using Chronicae.Server.Services;

namespace Chronicae.Server.Controllers
{
    [ApiController]
    [Route("api/projects/{projectId}/notes")]
    public class NotesController : ControllerBase
    {
        private readonly INoteRepository _noteRepository;
        private readonly IExportService _exportService;
        private readonly EventBroadcastService _eventBroadcastService;
        private readonly ILogger<NotesController> _logger;

        public NotesController(
            INoteRepository noteRepository,
            IExportService exportService,
            EventBroadcastService eventBroadcastService,
            ILogger<NotesController> logger)
        {
            _noteRepository = noteRepository;
            _exportService = exportService;
            _eventBroadcastService = eventBroadcastService;
            _logger = logger;
        }

        /// <summary>
        /// Gets notes for a project with cursor-based pagination and optional search
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="cursor">Cursor for pagination</param>
        /// <param name="limit">Maximum number of notes to return</param>
        /// <param name="search">Optional search query</param>
        /// <returns>List of notes with pagination cursor</returns>
        [HttpGet]
        public async Task<ActionResult<NoteListResponse>> GetNotes(
            Guid projectId,
            [FromQuery] string? cursor = null,
            [FromQuery] int limit = 50,
            [FromQuery] string? search = null)
        {
            try
            {
                // Validate limit
                if (limit <= 0 || limit > 100)
                {
                    return BadRequest(new { code = "invalid_request", message = "Limit must be between 1 and 100" });
                }

                var result = await _noteRepository.GetByProjectAsync(projectId, cursor, limit, search);
                
                return Ok(new NoteListResponse 
                { 
                    Items = result.Items, 
                    NextCursor = result.NextCursor 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving notes for project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve notes" });
            }
        }

        /// <summary>
        /// Creates a new note
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="request">Note creation request</param>
        /// <returns>Created note</returns>
        [HttpPost]
        public async Task<ActionResult<NoteResponse>> CreateNote(Guid projectId, [FromBody] CreateNoteRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Title))
            {
                return BadRequest(new { code = "invalid_request", message = "Note title is required" });
            }

            if (string.IsNullOrWhiteSpace(request.Content))
            {
                return BadRequest(new { code = "invalid_request", message = "Note content is required" });
            }

            try
            {
                var note = await _noteRepository.CreateAsync(
                    projectId, 
                    request.Title.Trim(), 
                    request.Content, 
                    request.Tags ?? new List<string>());
                
                if (note == null)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                // Broadcast note created event
                await _eventBroadcastService.PublishNoteCreatedAsync(note);
                
                return CreatedAtAction(
                    nameof(GetNote), 
                    new { projectId, noteId = note.Id }, 
                    new NoteResponse { Note = note });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating note in project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to create note" });
            }
        }

        /// <summary>
        /// Gets a specific note by ID
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <returns>Note details</returns>
        [HttpGet("{noteId}")]
        public async Task<ActionResult<NoteResponse>> GetNote(Guid projectId, Guid noteId)
        {
            try
            {
                var note = await _noteRepository.GetByIdAsync(projectId, noteId);
                if (note == null)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                return Ok(new NoteResponse { Note = note });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve note" });
            }
        }

        /// <summary>
        /// Updates an existing note (full update)
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="request">Note update request</param>
        /// <returns>Updated note or conflict response</returns>
        [HttpPut("{noteId}")]
        public async Task<ActionResult<NoteResponse>> UpdateNote(
            Guid projectId, 
            Guid noteId, 
            [FromBody] UpdateNoteRequest request)
        {
            try
            {
                // Extract version from If-Match header if present
                var ifMatch = Request.Headers["If-Match"].FirstOrDefault();
                var lastKnownVersion = request.LastKnownVersion ?? ParseIfMatchVersion(ifMatch);

                var result = await _noteRepository.UpdateAsync(
                    projectId, 
                    noteId, 
                    request.Title, 
                    request.Content, 
                    request.Tags, 
                    NoteUpdateMode.Full, 
                    lastKnownVersion);

                return result switch
                {
                    NoteUpdateResult.SuccessResult success => await HandleSuccessUpdate(success.Note),
                    NoteUpdateResult.ConflictResult conflict => Conflict(new NoteConflictResponse 
                    { 
                        Code = "note_conflict", 
                        Message = $"Note has been updated to version {conflict.CurrentNote.Version}. Refresh before retrying.",
                        Note = conflict.CurrentNote 
                    }),
                    NoteUpdateResult.NotFoundResult => NotFound(new { code = "note_not_found", message = "Note not found" }),
                    NoteUpdateResult.InvalidRequestResult => BadRequest(new { code = "invalid_request", message = "Invalid note payload" }),
                    _ => StatusCode(500, new { code = "internal_error", message = "Unexpected update result" })
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to update note" });
            }
        }

        /// <summary>
        /// Partially updates an existing note
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="request">Note partial update request</param>
        /// <returns>Updated note or conflict response</returns>
        [HttpPatch("{noteId}")]
        public async Task<ActionResult<NoteResponse>> PatchNote(
            Guid projectId, 
            Guid noteId, 
            [FromBody] UpdateNoteRequest request)
        {
            try
            {
                // Extract version from If-Match header if present
                var ifMatch = Request.Headers["If-Match"].FirstOrDefault();
                var lastKnownVersion = request.LastKnownVersion ?? ParseIfMatchVersion(ifMatch);

                var result = await _noteRepository.UpdateAsync(
                    projectId, 
                    noteId, 
                    request.Title, 
                    request.Content, 
                    request.Tags, 
                    NoteUpdateMode.Partial, 
                    lastKnownVersion);

                return result switch
                {
                    NoteUpdateResult.SuccessResult success => await HandleSuccessUpdate(success.Note),
                    NoteUpdateResult.ConflictResult conflict => Conflict(new NoteConflictResponse 
                    { 
                        Code = "note_conflict", 
                        Message = $"Note has been updated to version {conflict.CurrentNote.Version}. Refresh before retrying.",
                        Note = conflict.CurrentNote 
                    }),
                    NoteUpdateResult.NotFoundResult => NotFound(new { code = "note_not_found", message = "Note not found" }),
                    NoteUpdateResult.InvalidRequestResult => BadRequest(new { code = "invalid_request", message = "Invalid note payload" }),
                    _ => StatusCode(500, new { code = "internal_error", message = "Unexpected update result" })
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error patching note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to patch note" });
            }
        }

        /// <summary>
        /// Deletes a note with optional version purging
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="purgeVersions">Whether to delete all versions</param>
        /// <returns>No content if successful</returns>
        [HttpDelete("{noteId}")]
        public async Task<ActionResult> DeleteNote(
            Guid projectId, 
            Guid noteId, 
            [FromQuery] bool purgeVersions = false)
        {
            try
            {
                var deleted = await _noteRepository.DeleteAsync(projectId, noteId, purgeVersions);
                if (!deleted)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                // Broadcast note deleted event
                await _eventBroadcastService.PublishNoteDeletedAsync(noteId, projectId);

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to delete note" });
            }
        }

        /// <summary>
        /// Exports a note
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="format">Export format (md, pdf, txt)</param>
        /// <returns>Export job information</returns>
        [HttpPost("{noteId}/export")]
        public async Task<ActionResult> ExportNote(
            Guid projectId, 
            Guid noteId,
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

                // Check if note exists
                var note = await _noteRepository.GetByIdAsync(projectId, noteId);
                if (note == null)
                {
                    return NotFound(new { code = "note_not_found", message = "Note not found" });
                }

                // Generate export file path
                var exportDir = _exportService.GetExportDirectory();
                var timestamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss");
                var fileName = $"{SanitizeFileName(note.Title)}_{timestamp}.{format.ToLowerInvariant()}";
                var outputPath = Path.Combine(exportDir, fileName);

                // Export the note
                var exportedPath = await _exportService.ExportNoteAsync(note, format, outputPath);
                
                return Ok(new { 
                    message = "Note exported successfully",
                    filePath = exportedPath,
                    format = format,
                    fileName = Path.GetFileName(exportedPath)
                });
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Invalid export request for note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return BadRequest(new { code = "invalid_request", message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting note: {NoteId} in project: {ProjectId}", noteId, projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to export note" });
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

        private async Task<ActionResult<NoteResponse>> HandleSuccessUpdate(Note note)
        {
            await _eventBroadcastService.PublishNoteUpdatedAsync(note);
            return Ok(new NoteResponse { Note = note });
        }

        private static int? ParseIfMatchVersion(string? ifMatch)
        {
            if (string.IsNullOrWhiteSpace(ifMatch))
                return null;

            // Remove quotes if present (ETag format)
            var cleanValue = ifMatch.Trim('"');
            
            if (int.TryParse(cleanValue, out var version))
                return version;

            return null;
        }
    }
}