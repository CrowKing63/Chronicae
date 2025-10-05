using System;
using System.Threading.Tasks;
using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces
{
    public interface IBackupService
    {
        /// <summary>
        /// Creates a backup of all projects, notes, and versions as a ZIP file
        /// </summary>
        /// <returns>Backup record with operation details</returns>
        Task<BackupRecord> CreateBackupAsync();
        
        /// <summary>
        /// Gets the backup directory path
        /// </summary>
        /// <returns>Full path to the backup directory</returns>
        string GetBackupDirectory();
    }
}