using System;
using System.Collections.Generic;

namespace Chronicae.Core.Models
{
    public class Project
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int NoteCount { get; set; }
        public DateTime? LastIndexedAt { get; set; }
        public ProjectStats? Stats { get; set; }
        
        // Navigation properties
        public ICollection<Note> Notes { get; set; } = new List<Note>();
    }
}