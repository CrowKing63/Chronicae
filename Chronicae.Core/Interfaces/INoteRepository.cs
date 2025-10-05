using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces
{
    public interface INoteRepository
    {
        /// <summary>
        /// Gets notes for a project with cursor-based pagination and optional search
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="cursor">Cursor for pagination (base64 encoded)</param>
        /// <param name="limit">Maximum number of notes to return</param>
        /// <param name="search">Optional search query</param>
        /// <returns>Tuple of notes and next cursor</returns>
        Task<(IEnumerable<Note> Items, string? NextCursor)> GetByProjectAsync(
            Guid projectId, string? cursor = null, int limit = 50, string? search = null);
        
        /// <summary>
        /// Gets a specific note by ID
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <returns>Note if found, null otherwise</returns>
        Task<Note?> GetByIdAsync(Guid projectId, Guid noteId);
        
        /// <summary>
        /// Creates a new note with automatic version creation
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="title">Note title</param>
        /// <param name="content">Note content</param>
        /// <param name="tags">Note tags</param>
        /// <returns>Created note if project exists, null otherwise</returns>
        Task<Note?> CreateAsync(Guid projectId, string title, string content, List<string> tags);
        
        /// <summary>
        /// Updates an existing note with version conflict detection
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="title">New title (null to keep existing)</param>
        /// <param name="content">New content (null to keep existing)</param>
        /// <param name="tags">New tags (null to keep existing)</param>
        /// <param name="mode">Update mode (Full or Partial)</param>
        /// <param name="lastKnownVersion">Last known version for conflict detection</param>
        /// <returns>Update result indicating success, conflict, or not found</returns>
        Task<NoteUpdateResult> UpdateAsync(
            Guid projectId, Guid noteId, string? title, string? content, 
            List<string>? tags, NoteUpdateMode mode, int? lastKnownVersion);
        
        /// <summary>
        /// Deletes a note with optional version purging
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="noteId">Note ID</param>
        /// <param name="purgeVersions">Whether to delete all versions</param>
        /// <returns>True if deleted, false if not found</returns>
        Task<bool> DeleteAsync(Guid projectId, Guid noteId, bool purgeVersions = false);
        
        /// <summary>
        /// Searches notes across projects or within a specific project
        /// </summary>
        /// <param name="projectId">Project ID to search within (null for all projects)</param>
        /// <param name="query">Search query</param>
        /// <param name="mode">Search mode (Keyword or Semantic)</param>
        /// <param name="limit">Maximum number of results</param>
        /// <returns>Search results with relevance scores</returns>
        Task<IEnumerable<SearchResult>> SearchAsync(
            Guid? projectId, string query, SearchMode mode, int limit);
    }
    
    /// <summary>
    /// Result of a note update operation
    /// </summary>
    public abstract class NoteUpdateResult
    {
        public static NoteUpdateResult Success(Note note) => new SuccessResult(note);
        public static NoteUpdateResult Conflict(Note currentNote) => new ConflictResult(currentNote);
        public static NoteUpdateResult NotFound() => new NotFoundResult();
        public static NoteUpdateResult InvalidRequest() => new InvalidRequestResult();
        
        public sealed class SuccessResult : NoteUpdateResult
        {
            public Note Note { get; }
            public SuccessResult(Note note) => Note = note;
        }
        
        public sealed class ConflictResult : NoteUpdateResult
        {
            public Note CurrentNote { get; }
            public ConflictResult(Note currentNote) => CurrentNote = currentNote;
        }
        
        public sealed class NotFoundResult : NoteUpdateResult { }
        
        public sealed class InvalidRequestResult : NoteUpdateResult { }
    }
}