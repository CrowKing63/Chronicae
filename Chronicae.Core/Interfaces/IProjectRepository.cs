using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces
{
    public interface IProjectRepository
    {
        /// <summary>
        /// Gets all projects with optional statistics
        /// </summary>
        /// <param name="includeStats">Whether to include computed statistics</param>
        /// <returns>Collection of projects</returns>
        Task<IEnumerable<Project>> GetAllAsync(bool includeStats = false);
        
        /// <summary>
        /// Gets a project by ID with optional statistics
        /// </summary>
        /// <param name="id">Project ID</param>
        /// <param name="includeStats">Whether to include computed statistics</param>
        /// <returns>Project if found, null otherwise</returns>
        Task<Project?> GetByIdAsync(Guid id, bool includeStats = false);
        
        /// <summary>
        /// Creates a new project
        /// </summary>
        /// <param name="name">Project name</param>
        /// <returns>Created project</returns>
        Task<Project> CreateAsync(string name);
        
        /// <summary>
        /// Updates an existing project
        /// </summary>
        /// <param name="id">Project ID</param>
        /// <param name="name">New project name</param>
        /// <returns>Updated project if found, null otherwise</returns>
        Task<Project?> UpdateAsync(Guid id, string name);
        
        /// <summary>
        /// Deletes a project and all its notes
        /// </summary>
        /// <param name="id">Project ID</param>
        /// <returns>True if deleted, false if not found</returns>
        Task<bool> DeleteAsync(Guid id);
        
        /// <summary>
        /// Switches the active project
        /// </summary>
        /// <param name="id">Project ID to make active</param>
        /// <returns>Project if found and switched, null otherwise</returns>
        Task<Project?> SwitchActiveAsync(Guid id);
        
        /// <summary>
        /// Resets a project by deleting all its notes and versions
        /// </summary>
        /// <param name="id">Project ID</param>
        /// <returns>Project if found and reset, null otherwise</returns>
        Task<Project?> ResetAsync(Guid id);
        
        /// <summary>
        /// Gets the currently active project ID
        /// </summary>
        /// <returns>Active project ID if set, null otherwise</returns>
        Task<Guid?> GetActiveProjectIdAsync();
    }
}