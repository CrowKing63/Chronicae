using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;

namespace Chronicae.Data.Repositories
{
    public class VersionRepository : IVersionRepository
    {
        private readonly ChronicaeDbContext _context;
        
        public VersionRepository(ChronicaeDbContext context)
        {
            _context = context;
        }
        
        public async Task<IEnumerable<NoteVersion>> GetByNoteAsync(Guid noteId, int limit = 50)
        {
            return await _context.NoteVersions
                .Where(v => v.NoteId == noteId)
                .OrderByDescending(v => v.CreatedAt)
                .ThenByDescending(v => v.Version)
                .Take(limit)
                .ToListAsync();
        }
        
        public async Task<(NoteVersion Version, string Content)?> GetDetailAsync(Guid noteId, Guid versionId)
        {
            var version = await _context.NoteVersions
                .FirstOrDefaultAsync(v => v.Id == versionId && v.NoteId == noteId);
                
            if (version == null)
                return null;
                
            return (version, version.Content);
        }
        
        public async Task<NoteVersion?> RestoreAsync(Guid noteId, Guid versionId)
        {
            // Get the version to restore from
            var sourceVersion = await _context.NoteVersions
                .FirstOrDefaultAsync(v => v.Id == versionId && v.NoteId == noteId);
                
            if (sourceVersion == null)
                return null;
            
            // Get the current note
            var note = await _context.Notes.FindAsync(noteId);
            if (note == null)
                return null;
            
            // Update the note with the version's content
            note.Title = sourceVersion.Title;
            note.Content = sourceVersion.Content;
            note.Excerpt = sourceVersion.Excerpt;
            note.UpdatedAt = DateTime.UtcNow;
            note.Version++;
            
            // Create a new version with the restored content
            var newVersion = await CreateVersionAsync(
                noteId, 
                sourceVersion.Title, 
                sourceVersion.Content, 
                sourceVersion.Excerpt, 
                note.Version);
            
            // Update project's last indexed time
            var project = await _context.Projects.FindAsync(note.ProjectId);
            if (project != null)
            {
                project.LastIndexedAt = note.UpdatedAt;
            }
            
            await _context.SaveChangesAsync();
            
            return newVersion;
        }
        
        public async Task<NoteVersion> CreateVersionAsync(Guid noteId, string title, string content, string? excerpt, int version)
        {
            var noteVersion = new NoteVersion
            {
                Id = Guid.NewGuid(),
                NoteId = noteId,
                Title = title,
                Content = content,
                Excerpt = excerpt,
                CreatedAt = DateTime.UtcNow,
                Version = version
            };
            
            _context.NoteVersions.Add(noteVersion);
            
            // Note: SaveChangesAsync is called by the caller to allow for transactional operations
            
            return noteVersion;
        }
        
        /// <summary>
        /// Gets the latest version for a note
        /// </summary>
        public async Task<NoteVersion?> GetLatestVersionAsync(Guid noteId)
        {
            return await _context.NoteVersions
                .Where(v => v.NoteId == noteId)
                .OrderByDescending(v => v.Version)
                .FirstOrDefaultAsync();
        }
        
        /// <summary>
        /// Gets a specific version by version number
        /// </summary>
        public async Task<NoteVersion?> GetByVersionNumberAsync(Guid noteId, int versionNumber)
        {
            return await _context.NoteVersions
                .FirstOrDefaultAsync(v => v.NoteId == noteId && v.Version == versionNumber);
        }
        
        /// <summary>
        /// Deletes old versions beyond a certain limit to manage storage
        /// </summary>
        public async Task<int> CleanupOldVersionsAsync(Guid noteId, int keepLatestCount = 50)
        {
            var versionsToDelete = await _context.NoteVersions
                .Where(v => v.NoteId == noteId)
                .OrderByDescending(v => v.CreatedAt)
                .Skip(keepLatestCount)
                .ToListAsync();
            
            if (versionsToDelete.Any())
            {
                _context.NoteVersions.RemoveRange(versionsToDelete);
                await _context.SaveChangesAsync();
            }
            
            return versionsToDelete.Count;
        }
        
        /// <summary>
        /// Gets version statistics for a note
        /// </summary>
        public async Task<(int TotalVersions, DateTime? OldestVersion, DateTime? NewestVersion)> GetVersionStatsAsync(Guid noteId)
        {
            var versions = await _context.NoteVersions
                .Where(v => v.NoteId == noteId)
                .Select(v => v.CreatedAt)
                .ToListAsync();
            
            if (!versions.Any())
                return (0, null, null);
            
            return (
                TotalVersions: versions.Count,
                OldestVersion: versions.Min(),
                NewestVersion: versions.Max()
            );
        }
    }
}