using System;
using System.Collections.Generic;
using Chronicae.Core.Models;

namespace Chronicae.Server.Models
{
    // Response DTOs
    public class VersionListResponse
    {
        public IEnumerable<NoteVersion> Items { get; set; } = new List<NoteVersion>();
    }

    public class VersionDetailResponse
    {
        public NoteVersion Version { get; set; } = null!;
        public string Content { get; set; } = string.Empty;
    }

    public class VersionResponse
    {
        public NoteVersion Version { get; set; } = null!;
    }
}