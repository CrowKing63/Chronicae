using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;

namespace Chronicae.Data.Repositories
{
    public class BackupRepository : IBackupRepository
    {
        private readonly ChronicaeDbContext _context;
        
        public BackupRepository(ChronicaeDbContext context)
        {
            _context = context;
        }
        
        public async Task<BackupRecord> RunBackupAsync()
        {
            // This method should not be implemented here as it creates circular dependency
            // The backup creation logic should be handled by BackupService
            // This method is kept for interface compatibility but should not be used directly
            throw new NotImplementedException("Use BackupService.CreateBackupAsync() instead");
        }
        
        public async Task<BackupRecord> SaveBackupRecordAsync(BackupRecord backupRecord)
        {
            _context.BackupRecords.Add(backupRecord);
            await _context.SaveChangesAsync();
            return backupRecord;
        }
        
        public async Task<IEnumerable<BackupRecord>> GetHistoryAsync()
        {
            return await _context.BackupRecords
                .OrderByDescending(b => b.StartedAt)
                .ToListAsync();
        }
        
        public async Task<BackupRecord?> GetByIdAsync(Guid id)
        {
            return await _context.BackupRecords.FindAsync(id);
        }
        
        public async Task<int> CleanupOldBackupsAsync(int retentionDays = 30)
        {
            var cutoffDate = DateTime.UtcNow.AddDays(-retentionDays);
            
            var oldBackups = await _context.BackupRecords
                .Where(b => b.StartedAt < cutoffDate)
                .ToListAsync();
            
            int deletedCount = 0;
            
            foreach (var backup in oldBackups)
            {
                try
                {
                    // Delete the backup file if it exists
                    if (!string.IsNullOrEmpty(backup.ArtifactPath) && File.Exists(backup.ArtifactPath))
                    {
                        File.Delete(backup.ArtifactPath);
                    }
                    
                    // Remove the backup record
                    _context.BackupRecords.Remove(backup);
                    deletedCount++;
                }
                catch (Exception)
                {
                    // Continue with other backups if one fails to delete
                    continue;
                }
            }
            
            if (deletedCount > 0)
            {
                await _context.SaveChangesAsync();
            }
            
            return deletedCount;
        }
    }
}