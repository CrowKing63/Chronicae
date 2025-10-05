using Microsoft.AspNetCore.Mvc;
using Chronicae.Core.Interfaces;
using Chronicae.Server.Models;
using Chronicae.Server.Services;

namespace Chronicae.Server.Controllers
{
    [ApiController]
    [Route("api/projects")]
    public class ProjectsController : ControllerBase
    {
        private readonly IProjectRepository _projectRepository;
        private readonly IExportService _exportService;
        private readonly EventBroadcastService _eventBroadcastService;
        private readonly ILogger<ProjectsController> _logger;

        public ProjectsController(
            IProjectRepository projectRepository,
            IExportService exportService,
            EventBroadcastService eventBroadcastService,
            ILogger<ProjectsController> logger)
        {
            _projectRepository = projectRepository;
            _exportService = exportService;
            _eventBroadcastService = eventBroadcastService;
            _logger = logger;
        }

        /// <summary>
        /// Gets all projects with optional statistics
        /// </summary>
        /// <param name="includeStats">Whether to include computed statistics</param>
        /// <returns>List of projects with active project ID</returns>
        [HttpGet]
        public async Task<ActionResult<ProjectListResponse>> GetProjects([FromQuery] bool includeStats = false)
        {
            try
            {
                var projects = await _projectRepository.GetAllAsync(includeStats);
                var activeProjectId = await _projectRepository.GetActiveProjectIdAsync();
                
                return Ok(new ProjectListResponse 
                { 
                    Items = projects, 
                    ActiveProjectId = activeProjectId 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving projects");
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve projects" });
            }
        }

        /// <summary>
        /// Creates a new project
        /// </summary>
        /// <param name="request">Project creation request</param>
        /// <returns>Created project</returns>
        [HttpPost]
        public async Task<ActionResult<ProjectResponse>> CreateProject([FromBody] CreateProjectRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return BadRequest(new { code = "invalid_request", message = "Project name is required" });
            }

            try
            {
                var project = await _projectRepository.CreateAsync(request.Name.Trim());
                var activeProjectId = await _projectRepository.GetActiveProjectIdAsync();
                
                return CreatedAtAction(
                    nameof(GetProject), 
                    new { projectId = project.Id }, 
                    new ProjectResponse 
                    { 
                        Project = project, 
                        ActiveProjectId = activeProjectId 
                    });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating project with name: {ProjectName}", request.Name);
                return StatusCode(500, new { code = "internal_error", message = "Failed to create project" });
            }
        }

        /// <summary>
        /// Gets a specific project by ID
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="includeStats">Whether to include computed statistics</param>
        /// <returns>Project details</returns>
        [HttpGet("{projectId}")]
        public async Task<ActionResult<ProjectDetailResponse>> GetProject(Guid projectId, [FromQuery] bool includeStats = false)
        {
            try
            {
                var project = await _projectRepository.GetByIdAsync(projectId, includeStats);
                if (project == null)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                return Ok(new ProjectDetailResponse { Project = project });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve project" });
            }
        }

        /// <summary>
        /// Updates an existing project
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="request">Project update request</param>
        /// <returns>Updated project</returns>
        [HttpPut("{projectId}")]
        public async Task<ActionResult<ProjectResponse>> UpdateProject(Guid projectId, [FromBody] UpdateProjectRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return BadRequest(new { code = "invalid_request", message = "Project name is required" });
            }

            try
            {
                var project = await _projectRepository.UpdateAsync(projectId, request.Name.Trim());
                if (project == null)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                var activeProjectId = await _projectRepository.GetActiveProjectIdAsync();
                
                return Ok(new ProjectResponse 
                { 
                    Project = project, 
                    ActiveProjectId = activeProjectId 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to update project" });
            }
        }

        /// <summary>
        /// Deletes a project and all its notes
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <returns>No content if successful</returns>
        [HttpDelete("{projectId}")]
        public async Task<ActionResult> DeleteProject(Guid projectId)
        {
            try
            {
                var deleted = await _projectRepository.DeleteAsync(projectId);
                if (!deleted)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to delete project" });
            }
        }

        /// <summary>
        /// Switches the active project
        /// </summary>
        /// <param name="projectId">Project ID to make active</param>
        /// <returns>Switched project</returns>
        [HttpPost("{projectId}/switch")]
        public async Task<ActionResult<ProjectResponse>> SwitchProject(Guid projectId)
        {
            try
            {
                var project = await _projectRepository.SwitchActiveAsync(projectId);
                if (project == null)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                // Broadcast project switched event
                await _eventBroadcastService.PublishProjectSwitchedAsync(project);
                
                var activeProjectId = await _projectRepository.GetActiveProjectIdAsync();
                
                return Ok(new ProjectResponse 
                { 
                    Project = project, 
                    ActiveProjectId = activeProjectId 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error switching to project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to switch project" });
            }
        }

        /// <summary>
        /// Resets a project by deleting all its notes and versions
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <returns>Reset project</returns>
        [HttpPost("{projectId}/reset")]
        public async Task<ActionResult<ProjectResponse>> ResetProject(Guid projectId)
        {
            try
            {
                var project = await _projectRepository.ResetAsync(projectId);
                if (project == null)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                var activeProjectId = await _projectRepository.GetActiveProjectIdAsync();
                
                return Ok(new ProjectResponse 
                { 
                    Project = project, 
                    ActiveProjectId = activeProjectId 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error resetting project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to reset project" });
            }
        }

        /// <summary>
        /// Exports a project
        /// </summary>
        /// <param name="projectId">Project ID</param>
        /// <param name="format">Export format (zip, json)</param>
        /// <returns>Export job information</returns>
        [HttpPost("{projectId}/export")]
        public async Task<ActionResult> ExportProject(
            Guid projectId,
            [FromQuery] string format = "zip")
        {
            try
            {
                // Validate format
                var validFormats = new[] { "zip", "json" };
                if (!validFormats.Contains(format.ToLowerInvariant()))
                {
                    return BadRequest(new { 
                        code = "invalid_format", 
                        message = $"Invalid format. Supported formats: {string.Join(", ", validFormats)}" 
                    });
                }

                // Check if project exists
                var project = await _projectRepository.GetByIdAsync(projectId);
                if (project == null)
                {
                    return NotFound(new { code = "project_not_found", message = "Project not found" });
                }

                // Generate export file path
                var exportDir = _exportService.GetExportDirectory();
                var timestamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss");
                var fileName = $"{SanitizeFileName(project.Name)}_{timestamp}.{format.ToLowerInvariant()}";
                var outputPath = Path.Combine(exportDir, fileName);

                // Export the project
                var exportedPath = await _exportService.ExportProjectAsync(projectId, format, outputPath);
                
                return Ok(new { 
                    message = "Project exported successfully",
                    filePath = exportedPath,
                    format = format,
                    fileName = Path.GetFileName(exportedPath)
                });
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Invalid export request for project: {ProjectId}", projectId);
                return BadRequest(new { code = "invalid_request", message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting project: {ProjectId}", projectId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to export project" });
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