using System;

namespace Chronicae.Core.Models
{
    public class NoteVersion
    {
        public Guid Id { get; set; }
        public Guid NoteId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string? Excerpt { get; set; }
        public DateTime CreatedAt { get; set; }
        public int Version { get; set; }
        
        // Navigation properties
        public Note Note { get; set; } = null!;
    }
}