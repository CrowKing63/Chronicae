using System;
using System.Collections.Generic;

namespace Chronicae.Core.Models
{
    public class Note
    {
        public Guid Id { get; set; }
        public Guid ProjectId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string? Excerpt { get; set; }
        public List<string> Tags { get; set; } = new List<string>();
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int Version { get; set; }
        
        // Navigation properties
        public Project Project { get; set; } = null!;
        public ICollection<NoteVersion> Versions { get; set; } = new List<NoteVersion>();
    }
}