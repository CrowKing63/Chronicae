using System;
using System.Collections.Generic;
using Chronicae.Core.Models;

namespace Chronicae.Server.Models
{
    // Request DTOs
    public class CreateProjectRequest
    {
        public string Name { get; set; } = string.Empty;
    }

    public class UpdateProjectRequest
    {
        public string Name { get; set; } = string.Empty;
    }

    // Response DTOs
    public class ProjectListResponse
    {
        public IEnumerable<Project> Items { get; set; } = new List<Project>();
        public Guid? ActiveProjectId { get; set; }
    }

    public class ProjectResponse
    {
        public Project Project { get; set; } = null!;
        public Guid? ActiveProjectId { get; set; }
    }

    public class ProjectDetailResponse
    {
        public Project Project { get; set; } = null!;
    }
}