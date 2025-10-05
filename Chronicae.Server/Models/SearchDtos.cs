using System;
using System.Collections.Generic;
using Chronicae.Core.Models;

namespace Chronicae.Server.Models
{
    // Response DTOs
    public class SearchResponse
    {
        public IEnumerable<SearchResult> Items { get; set; } = new List<SearchResult>();
        public string Query { get; set; } = string.Empty;
        public SearchMode Mode { get; set; }
        public Guid? ProjectId { get; set; }
        public int TotalResults { get; set; }
    }
}