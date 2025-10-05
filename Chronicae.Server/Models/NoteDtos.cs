using System;
using System.Collections.Generic;
using Chronicae.Core.Models;

namespace Chronicae.Server.Models
{
    // Request DTOs
    public class CreateNoteRequest
    {
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public List<string> Tags { get; set; } = new List<string>();
    }

    public class UpdateNoteRequest
    {
        public string? Title { get; set; }
        public string? Content { get; set; }
        public List<string>? Tags { get; set; }
        public int? LastKnownVersion { get; set; }
    }

    // Response DTOs
    public class NoteListResponse
    {
        public IEnumerable<Note> Items { get; set; } = new List<Note>();
        public string? NextCursor { get; set; }
    }

    public class NoteResponse
    {
        public Note Note { get; set; } = null!;
    }

    public class NoteConflictResponse
    {
        public string Code { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public Note Note { get; set; } = null!;
    }
}