using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;

namespace Chronicae.Data.Repositories
{
    public class ProjectRepository : IProjectRepository
    {
        private readonly ChronicaeDbContext _context;
        
        public ProjectRepository(ChronicaeDbContext context)
        {
            _context = context;
        }
        
        public async Task<IEnumerable<Project>> GetAllAsync(bool includeStats = false)
        {
            var query = _context.Projects.AsQueryable();
            
            if (includeStats)
            {
                // Include notes for statistics calculation
                query = query.Include(p => p.Notes);
            }
            
            var projects = await query.OrderBy(p => p.Name).ToListAsync();
            
            if (includeStats)
            {
                // Calculate statistics for each project
                foreach (var project in projects)
                {
                    project.Stats = await CalculateProjectStatsAsync(project.Id);
                }
            }
            
            return projects;
        }
        
        public async Task<Project?> GetByIdAsync(Guid id, bool includeStats = false)
        {
            var query = _context.Projects.Where(p => p.Id == id);
            
            if (includeStats)
            {
                query = query.Include(p => p.Notes);
            }
            
            var project = await query.FirstOrDefaultAsync();
            
            if (project != null && includeStats)
            {
                project.Stats = await CalculateProjectStatsAsync(project.Id);
            }
            
            return project;
        }
        
        public async Task<Project> CreateAsync(string name)
        {
            var project = new Project
            {
                Id = Guid.NewGuid(),
                Name = name.Trim(),
                NoteCount = 0,
                LastIndexedAt = null
            };
            
            _context.Projects.Add(project);
            await _context.SaveChangesAsync();
            
            return project;
        }
        
        public async Task<Project?> UpdateAsync(Guid id, string name)
        {
            var project = await _context.Projects.FindAsync(id);
            if (project == null)
                return null;
            
            project.Name = name.Trim();
            await _context.SaveChangesAsync();
            
            return project;
        }
        
        public async Task<bool> DeleteAsync(Guid id)
        {
            var project = await _context.Projects.FindAsync(id);
            if (project == null)
                return false;
            
            // EF Core will cascade delete all notes and versions due to the configured relationships
            _context.Projects.Remove(project);
            await _context.SaveChangesAsync();
            
            return true;
        }
        
        public async Task<Project?> SwitchActiveAsync(Guid id)
        {
            var project = await _context.Projects.FindAsync(id);
            if (project == null)
                return null;
            
            // TODO: Store active project ID in ServerConfigurationService when it's implemented
            // For now, we'll just return the project to indicate success
            
            return project;
        }
        
        public async Task<Project?> ResetAsync(Guid id)
        {
            var project = await _context.Projects
                .Include(p => p.Notes)
                .ThenInclude(n => n.Versions)
                .FirstOrDefaultAsync(p => p.Id == id);
                
            if (project == null)
                return null;
            
            // Remove all notes and their versions (cascade delete will handle versions)
            _context.Notes.RemoveRange(project.Notes);
            
            // Reset project statistics
            project.NoteCount = 0;
            project.LastIndexedAt = null;
            
            await _context.SaveChangesAsync();
            
            return project;
        }
        
        public async Task<Guid?> GetActiveProjectIdAsync()
        {
            // TODO: Get active project ID from ServerConfigurationService when it's implemented
            // For now, return the first project if any exists
            var firstProject = await _context.Projects.FirstOrDefaultAsync();
            return firstProject?.Id;
        }
        
        /// <summary>
        /// Calculates statistics for a project
        /// </summary>
        private async Task<ProjectStats> CalculateProjectStatsAsync(Guid projectId)
        {
            var notes = await _context.Notes
                .Where(n => n.ProjectId == projectId)
                .ToListAsync();
            
            var versionCount = await _context.NoteVersions
                .Where(v => _context.Notes.Any(n => n.Id == v.NoteId && n.ProjectId == projectId))
                .CountAsync();
            
            var latestNoteUpdatedAt = notes.Any() 
                ? notes.Max(n => n.UpdatedAt) 
                : (DateTime?)null;
            
            var uniqueTags = notes
                .SelectMany(n => n.Tags)
                .Distinct()
                .Count();
            
            var averageNoteLength = notes.Any() 
                ? notes.Average(n => n.Content.Length) 
                : 0.0;
            
            return new ProjectStats
            {
                VersionCount = versionCount,
                LatestNoteUpdatedAt = latestNoteUpdatedAt,
                UniqueTagCount = uniqueTags,
                AverageNoteLength = averageNoteLength
            };
        }
    }
}