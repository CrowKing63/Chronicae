using System;

namespace Chronicae.Core.Models
{
    public class ExportJob
    {
        public Guid Id { get; set; }
        public Guid? ProjectId { get; set; }
        public Guid? NoteId { get; set; }
        public Guid? VersionId { get; set; }
        public string Format { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime? CompletedAt { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? ArtifactPath { get; set; }
        public string? ErrorMessage { get; set; }
        
        // Navigation properties
        public Project? Project { get; set; }
        public Note? Note { get; set; }
        public NoteVersion? Version { get; set; }
    }
}