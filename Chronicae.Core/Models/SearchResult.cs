using System;
using System.Collections.Generic;

namespace Chronicae.Core.Models
{
    public class SearchResult
    {
        public Guid NoteId { get; set; }
        public Guid ProjectId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Snippet { get; set; } = string.Empty;
        public List<string> Tags { get; set; } = new List<string>();
        public double Score { get; set; }
        public DateTime UpdatedAt { get; set; }
        
        // Navigation properties
        public Note Note { get; set; } = null!;
        public Project Project { get; set; } = null!;
    }
}