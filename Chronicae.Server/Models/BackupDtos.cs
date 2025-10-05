using System;
using System.Collections.Generic;
using Chronicae.Core.Models;

namespace Chronicae.Server.Models
{
    // Response DTOs
    public class BackupResponse
    {
        public BackupRecord Backup { get; set; } = null!;
    }

    public class BackupHistoryResponse
    {
        public IEnumerable<BackupRecord> Items { get; set; } = new List<BackupRecord>();
    }
}