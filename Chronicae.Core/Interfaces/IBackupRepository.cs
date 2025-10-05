using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces
{
    public interface IBackupRepository
    {
        /// <summary>
        /// Runs a backup operation, creating a ZIP file with all projects, notes, and versions
        /// </summary>
        /// <returns>Backup record with operation details</returns>
        Task<BackupRecord> RunBackupAsync();
        
        /// <summary>
        /// Saves a backup record to the database
        /// </summary>
        /// <param name="backupRecord">Backup record to save</param>
        /// <returns>Saved backup record</returns>
        Task<BackupRecord> SaveBackupRecordAsync(BackupRecord backupRecord);
        
        /// <summary>
        /// Gets backup history ordered by start date (newest first)
        /// </summary>
        /// <returns>Collection of backup records</returns>
        Task<IEnumerable<BackupRecord>> GetHistoryAsync();
        
        /// <summary>
        /// Gets a specific backup record by ID
        /// </summary>
        /// <param name="id">Backup record ID</param>
        /// <returns>Backup record if found, null otherwise</returns>
        Task<BackupRecord?> GetByIdAsync(Guid id);
        
        /// <summary>
        /// Deletes old backup files and records based on retention policy
        /// </summary>
        /// <param name="retentionDays">Number of days to retain backups</param>
        /// <returns>Number of backups deleted</returns>
        Task<int> CleanupOldBackupsAsync(int retentionDays = 30);
    }
}