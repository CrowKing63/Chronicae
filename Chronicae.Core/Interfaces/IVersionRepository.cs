using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces
{
    public interface IVersionRepository
    {
        /// <summary>
        /// Gets versions for a note ordered by creation date (newest first)
        /// </summary>
        /// <param name="noteId">Note ID</param>
        /// <param name="limit">Maximum number of versions to return</param>
        /// <returns>Collection of note versions</returns>
        Task<IEnumerable<NoteVersion>> GetByNoteAsync(Guid noteId, int limit = 50);
        
        /// <summary>
        /// Gets detailed information for a specific version
        /// </summary>
        /// <param name="noteId">Note ID</param>
        /// <param name="versionId">Version ID</param>
        /// <returns>Tuple of version and content if found, null otherwise</returns>
        Task<(NoteVersion Version, string Content)?> GetDetailAsync(Guid noteId, Guid versionId);
        
        /// <summary>
        /// Restores a note to a specific version by creating a new version with the restored content
        /// </summary>
        /// <param name="noteId">Note ID</param>
        /// <param name="versionId">Version ID to restore from</param>
        /// <returns>New version created from restoration if successful, null otherwise</returns>
        Task<NoteVersion?> RestoreAsync(Guid noteId, Guid versionId);
        
        /// <summary>
        /// Creates a new version snapshot for a note
        /// </summary>
        /// <param name="noteId">Note ID</param>
        /// <param name="title">Note title at time of version</param>
        /// <param name="content">Note content at time of version</param>
        /// <param name="excerpt">Note excerpt at time of version</param>
        /// <param name="version">Version number</param>
        /// <returns>Created version</returns>
        Task<NoteVersion> CreateVersionAsync(Guid noteId, string title, string content, string? excerpt, int version);
    }
}