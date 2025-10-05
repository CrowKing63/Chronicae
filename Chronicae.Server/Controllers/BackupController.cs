using Microsoft.AspNetCore.Mvc;
using Chronicae.Core.Interfaces;
using Chronicae.Server.Models;
using Chronicae.Server.Services;

namespace Chronicae.Server.Controllers
{
    [ApiController]
    [Route("api/backup")]
    public class BackupController : ControllerBase
    {
        private readonly IBackupRepository _backupRepository;
        private readonly IBackupService _backupService;
        private readonly EventBroadcastService _eventBroadcastService;
        private readonly ILogger<BackupController> _logger;

        public BackupController(
            IBackupRepository backupRepository,
            IBackupService backupService,
            EventBroadcastService eventBroadcastService,
            ILogger<BackupController> logger)
        {
            _backupRepository = backupRepository;
            _backupService = backupService;
            _eventBroadcastService = eventBroadcastService;
            _logger = logger;
        }

        /// <summary>
        /// Runs a backup operation, creating a ZIP file with all projects, notes, and versions
        /// </summary>
        /// <returns>Backup record with operation details</returns>
        [HttpPost("run")]
        public async Task<ActionResult<BackupResponse>> RunBackup()
        {
            try
            {
                _logger.LogInformation("Starting backup operation");
                
                var backupRecord = await _backupService.CreateBackupAsync();
                
                _logger.LogInformation("Backup operation completed with status: {Status}", backupRecord.Status);
                
                // Broadcast backup completed event
                await _eventBroadcastService.PublishBackupCompletedAsync(backupRecord);
                
                return Ok(new BackupResponse { Backup = backupRecord });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error running backup operation");
                return StatusCode(500, new { code = "internal_error", message = "Failed to run backup" });
            }
        }

        /// <summary>
        /// Gets backup history ordered by start date (newest first)
        /// </summary>
        /// <returns>List of backup records</returns>
        [HttpGet("history")]
        public async Task<ActionResult<BackupHistoryResponse>> GetBackupHistory()
        {
            try
            {
                var backupHistory = await _backupRepository.GetHistoryAsync();
                
                return Ok(new BackupHistoryResponse { Items = backupHistory });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving backup history");
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve backup history" });
            }
        }

        /// <summary>
        /// Gets a specific backup record by ID
        /// </summary>
        /// <param name="backupId">Backup record ID</param>
        /// <returns>Backup record details</returns>
        [HttpGet("{backupId}")]
        public async Task<ActionResult<BackupResponse>> GetBackup(Guid backupId)
        {
            try
            {
                var backup = await _backupRepository.GetByIdAsync(backupId);
                if (backup == null)
                {
                    return NotFound(new { code = "backup_not_found", message = "Backup not found" });
                }

                return Ok(new BackupResponse { Backup = backup });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving backup: {BackupId}", backupId);
                return StatusCode(500, new { code = "internal_error", message = "Failed to retrieve backup" });
            }
        }

        /// <summary>
        /// Deletes old backup files and records based on retention policy
        /// </summary>
        /// <param name="retentionDays">Number of days to retain backups (default: 30)</param>
        /// <returns>Number of backups deleted</returns>
        [HttpPost("cleanup")]
        public async Task<ActionResult> CleanupOldBackups([FromQuery] int retentionDays = 30)
        {
            try
            {
                if (retentionDays <= 0)
                {
                    return BadRequest(new { code = "invalid_request", message = "Retention days must be greater than 0" });
                }

                _logger.LogInformation("Starting backup cleanup with retention period: {RetentionDays} days", retentionDays);
                
                var deletedCount = await _backupRepository.CleanupOldBackupsAsync(retentionDays);
                
                _logger.LogInformation("Backup cleanup completed. Deleted {DeletedCount} old backups", deletedCount);
                
                return Ok(new { 
                    deletedCount, 
                    retentionDays,
                    message = $"Deleted {deletedCount} old backup(s)" 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during backup cleanup");
                return StatusCode(500, new { code = "internal_error", message = "Failed to cleanup old backups" });
            }
        }
    }
}