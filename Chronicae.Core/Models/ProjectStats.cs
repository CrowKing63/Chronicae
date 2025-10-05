using System;

namespace Chronicae.Core.Models
{
    public class ProjectStats
    {
        public int VersionCount { get; set; }
        public DateTime? LatestNoteUpdatedAt { get; set; }
        public int UniqueTagCount { get; set; }
        public double AverageNoteLength { get; set; }
    }
}