using System;

namespace Chronicae.Core.Models
{
    public class BackupRecord
    {
        public Guid Id { get; set; }
        public DateTime StartedAt { get; set; }
        public DateTime CompletedAt { get; set; }
        public BackupStatus Status { get; set; }
        public string? ArtifactPath { get; set; }
    }
}