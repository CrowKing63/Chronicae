using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;
using Chronicae.Core.Utilities;
using Chronicae.Data;

namespace Chronicae.Tests.Repositories
{
    /// <summary>
    /// Test-specific implementation of NoteRepository that works with InMemory database
    /// Uses Contains() instead of EF.Functions.Like() for compatibility
    /// </summary>
    public class TestNoteRepository : INoteRepository
    {
        private readonly ChronicaeDbContext _context;
        
        public TestNoteRepository(ChronicaeDbContext context)
        {
            _context = context;
        }
        
        public async Task<(IEnumerable<Note> Items, string? NextCursor)> GetByProjectAsync(
            Guid projectId, string? cursor = null, int limit = 50, string? search = null)
        {
            var query = _context.Notes
                .Where(n => n.ProjectId == projectId)
                .AsQueryable();
            
            // Apply search filter if provided - use Contains for InMemory compatibility
            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchTerm = search.Trim().ToLower();
                query = query.Where(n => 
                    n.Title.ToLower().Contains(searchTerm) ||
                    n.Content.ToLower().Contains(searchTerm) ||
                    (n.Excerpt != null && n.Excerpt.ToLower().Contains(searchTerm)));
                    // Skip tag search for InMemory as it doesn't support complex expressions
            }
            
            // Apply cursor-based pagination
            if (!string.IsNullOrWhiteSpace(cursor))
            {
                var decodedCursor = CursorPagination.DecodeCursor(cursor);
                if (decodedCursor.HasValue)
                {
                    var (updatedAt, createdAt, id) = decodedCursor.Value;
                    
                    // Filter notes that come after the cursor
                    query = query.Where(n => 
                        n.UpdatedAt < updatedAt || 
                        (n.UpdatedAt == updatedAt && n.CreatedAt < createdAt) ||
                        (n.UpdatedAt == updatedAt && n.CreatedAt == createdAt && n.Id.CompareTo(id) < 0));
                }
            }
            
            // Order by UpdatedAt desc, then CreatedAt desc, then Id for consistent pagination
            query = query.OrderByDescending(n => n.UpdatedAt)
                         .ThenByDescending(n => n.CreatedAt)
                         .ThenByDescending(n => n.Id);
            
            // Take one extra to determine if there's a next page
            var notes = await query.Take(limit + 1).ToListAsync();
            
            string? nextCursor = null;
            if (notes.Count > limit)
            {
                // Remove the extra note and create cursor from the last note
                var lastNote = notes[limit - 1];
                nextCursor = CursorPagination.CreateCursorFromNote(lastNote);
                notes = notes.Take(limit).ToList();
            }
            
            return (notes, nextCursor);
        }
        
        public async Task<Note?> GetByIdAsync(Guid projectId, Guid noteId)
        {
            return await _context.Notes
                .FirstOrDefaultAsync(n => n.Id == noteId && n.ProjectId == projectId);
        }
        
        public async Task<Note?> CreateAsync(Guid projectId, string title, string content, List<string> tags)
        {
            // Verify project exists
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);
            if (!projectExists)
                return null;
            
            var now = DateTime.UtcNow;
            var excerpt = GenerateExcerpt(content);
            
            var note = new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = projectId,
                Title = title.Trim(),
                Content = content,
                Excerpt = excerpt,
                Tags = tags ?? new List<string>(),
                CreatedAt = now,
                UpdatedAt = now,
                Version = 1
            };
            
            _context.Notes.Add(note);
            
            // Create initial version
            await CreateVersionAsync(note.Id, note.Title, note.Content, note.Excerpt, note.Version);
            
            // Update project note count
            var project = await _context.Projects.FindAsync(projectId);
            if (project != null)
            {
                project.NoteCount++;
                project.LastIndexedAt = now;
            }
            
            await _context.SaveChangesAsync();
            
            return note;
        }
        
        public async Task<NoteUpdateResult> UpdateAsync(
            Guid projectId, Guid noteId, string? title, string? content, 
            List<string>? tags, NoteUpdateMode mode, int? lastKnownVersion)
        {
            var note = await _context.Notes
                .FirstOrDefaultAsync(n => n.Id == noteId && n.ProjectId == projectId);
                
            if (note == null)
                return NoteUpdateResult.NotFound();
            
            // Check for version conflict if lastKnownVersion is provided
            if (lastKnownVersion.HasValue && note.Version != lastKnownVersion.Value)
            {
                return NoteUpdateResult.Conflict(note);
            }
            
            // Validate that at least one field is being updated
            if (mode == NoteUpdateMode.Full)
            {
                if (string.IsNullOrWhiteSpace(title) || content == null)
                    return NoteUpdateResult.InvalidRequest();
            }
            else // Partial mode
            {
                if (title == null && content == null && tags == null)
                    return NoteUpdateResult.InvalidRequest();
            }
            
            var hasChanges = false;
            
            // Apply updates based on mode
            if (mode == NoteUpdateMode.Full)
            {
                if (note.Title != title!.Trim())
                {
                    note.Title = title.Trim();
                    hasChanges = true;
                }
                
                if (note.Content != content!)
                {
                    note.Content = content;
                    hasChanges = true;
                }
                
                if (tags != null && !note.Tags.SequenceEqual(tags))
                {
                    note.Tags = tags;
                    hasChanges = true;
                }
            }
            else // Partial mode
            {
                if (title != null && note.Title != title.Trim())
                {
                    note.Title = title.Trim();
                    hasChanges = true;
                }
                
                if (content != null && note.Content != content)
                {
                    note.Content = content;
                    hasChanges = true;
                }
                
                if (tags != null && !note.Tags.SequenceEqual(tags))
                {
                    note.Tags = tags;
                    hasChanges = true;
                }
            }
            
            if (!hasChanges)
                return NoteUpdateResult.Success(note);
            
            // Update metadata
            note.UpdatedAt = DateTime.UtcNow;
            note.Version++;
            note.Excerpt = GenerateExcerpt(note.Content);
            
            // Create new version snapshot
            await CreateVersionAsync(note.Id, note.Title, note.Content, note.Excerpt, note.Version);
            
            // Update project's last indexed time
            var project = await _context.Projects.FindAsync(projectId);
            if (project != null)
            {
                project.LastIndexedAt = note.UpdatedAt;
            }
            
            await _context.SaveChangesAsync();
            
            return NoteUpdateResult.Success(note);
        }
        
        public async Task<bool> DeleteAsync(Guid projectId, Guid noteId, bool purgeVersions = false)
        {
            var note = await _context.Notes
                .Include(n => n.Versions)
                .FirstOrDefaultAsync(n => n.Id == noteId && n.ProjectId == projectId);
                
            if (note == null)
                return false;
            
            if (purgeVersions)
            {
                // Remove all versions explicitly
                _context.NoteVersions.RemoveRange(note.Versions);
            }
            
            // Remove the note (cascade delete will handle versions if not purged explicitly)
            _context.Notes.Remove(note);
            
            // Update project note count
            var project = await _context.Projects.FindAsync(projectId);
            if (project != null)
            {
                project.NoteCount = Math.Max(0, project.NoteCount - 1);
            }
            
            await _context.SaveChangesAsync();
            
            return true;
        }
        
        public async Task<IEnumerable<SearchResult>> SearchAsync(
            Guid? projectId, string query, SearchMode mode, int limit)
        {
            if (string.IsNullOrWhiteSpace(query))
                return Enumerable.Empty<SearchResult>();
            
            var searchTerm = query.Trim().ToLower();
            var notesQuery = _context.Notes.AsQueryable();
            
            // Filter by project if specified
            if (projectId.HasValue)
            {
                notesQuery = notesQuery.Where(n => n.ProjectId == projectId.Value);
            }
            
            // Apply search using Contains for InMemory compatibility
            notesQuery = notesQuery.Where(n => 
                n.Title.ToLower().Contains(searchTerm) ||
                n.Content.ToLower().Contains(searchTerm) ||
                (n.Excerpt != null && n.Excerpt.ToLower().Contains(searchTerm)));
                // Skip tag search for InMemory as it's complex
            
            var notes = await notesQuery
                .Include(n => n.Project)
                .Take(limit * 2) // Take more to allow for scoring and filtering
                .ToListAsync();
            
            // Calculate relevance scores and create search results
            var results = notes.Select(note => new SearchResult
            {
                NoteId = note.Id,
                ProjectId = note.ProjectId,
                Title = note.Title,
                Snippet = SnippetGenerator.GenerateSnippet(note.Content, searchTerm, note.Excerpt),
                Tags = note.Tags,
                Score = CalculateRelevanceScore(note, searchTerm),
                UpdatedAt = note.UpdatedAt,
                Note = note,
                Project = note.Project
            })
            .OrderByDescending(r => r.Score)
            .ThenByDescending(r => r.UpdatedAt)
            .Take(limit);
            
            return results;
        }
        
        /// <summary>
        /// Generates an excerpt from content (first 200 characters)
        /// </summary>
        private static string? GenerateExcerpt(string content)
        {
            if (string.IsNullOrWhiteSpace(content))
                return null;
            
            var trimmed = content.Trim();
            if (trimmed.Length <= 200)
                return trimmed;
            
            // Find a good break point near 200 characters
            var excerpt = trimmed.Substring(0, 200);
            var lastSpace = excerpt.LastIndexOf(' ');
            
            if (lastSpace > 150) // If there's a space reasonably close to the end
            {
                excerpt = excerpt.Substring(0, lastSpace);
            }
            
            return excerpt + "...";
        }
        
        /// <summary>
        /// Calculates relevance score for search results
        /// </summary>
        private static double CalculateRelevanceScore(Note note, string searchTerm)
        {
            double score = 0.0;
            var lowerSearchTerm = searchTerm.ToLower();
            
            // Title match (weight: 0.6)
            if (note.Title.ToLower().Contains(lowerSearchTerm))
            {
                score += 0.6;
                
                // Bonus for exact title match
                if (note.Title.ToLower() == lowerSearchTerm)
                    score += 0.2;
            }
            
            // Content match (weight: 0.3)
            if (note.Content.ToLower().Contains(lowerSearchTerm))
            {
                score += 0.3;
                
                // Bonus for multiple occurrences
                var occurrences = CountOccurrences(note.Content.ToLower(), lowerSearchTerm);
                score += Math.Min(0.2, occurrences * 0.05);
            }
            
            // Tag match (weight: 0.2) - simplified for InMemory
            if (note.Tags.Any(tag => tag.ToLower().Contains(lowerSearchTerm)))
            {
                score += 0.2;
                
                // Bonus for exact tag match
                if (note.Tags.Any(tag => tag.ToLower() == lowerSearchTerm))
                    score += 0.1;
            }
            
            return score;
        }
        
        /// <summary>
        /// Counts occurrences of a substring in a string
        /// </summary>
        private static int CountOccurrences(string text, string substring)
        {
            int count = 0;
            int index = 0;
            
            while ((index = text.IndexOf(substring, index)) != -1)
            {
                count++;
                index += substring.Length;
            }
            
            return count;
        }
        
        /// <summary>
        /// Creates a new version snapshot for a note
        /// </summary>
        private async Task<NoteVersion> CreateVersionAsync(Guid noteId, string title, string content, string? excerpt, int version)
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
            
            return noteVersion;
        }
    }
}