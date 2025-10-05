using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;

namespace Chronicae.Core.Services
{
    public class BackupService : IBackupService
    {
        private readonly IProjectRepository _projectRepository;
        private readonly INoteRepository _noteRepository;
        private readonly IVersionRepository _versionRepository;
        private readonly IBackupRepository _backupRepository;
        private readonly ILogger<BackupService> _logger;
        
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true,
            DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
        };

        public BackupService(
            IProjectRepository projectRepository,
            INoteRepository noteRepository,
            IVersionRepository versionRepository,
            IBackupRepository backupRepository,
            ILogger<BackupService> logger)
        {
            _projectRepository = projectRepository;
            _noteRepository = noteRepository;
            _versionRepository = versionRepository;
            _backupRepository = backupRepository;
            _logger = logger;
        }

        public async Task<BackupRecord> CreateBackupAsync()
        {
            var startedAt = DateTime.UtcNow;
            var timestamp = startedAt.ToString("yyyyMMdd-HHmmss");
            var backupDirectory = GetBackupDirectory();
            var backupFileName = $"chronicae-{timestamp}.zip";
            var backupPath = Path.Combine(backupDirectory, backupFileName);

            _logger.LogInformation("Starting backup operation to {BackupPath}", backupPath);

            try
            {
                // Ensure backup directory exists
                Directory.CreateDirectory(backupDirectory);

                // Create backup data structure
                var backupData = await CreateBackupDataAsync();

                // Create ZIP file with backup data
                await CreateZipFileAsync(backupPath, backupData);

                var completedAt = DateTime.UtcNow;
                var backupRecord = new BackupRecord
                {
                    Id = Guid.NewGuid(),
                    StartedAt = startedAt,
                    CompletedAt = completedAt,
                    Status = BackupStatus.Success,
                    ArtifactPath = backupPath
                };

                // Save backup record to database
                var savedRecord = await _backupRepository.SaveBackupRecordAsync(backupRecord);

                _logger.LogInformation("Backup completed successfully in {Duration}ms", 
                    (completedAt - startedAt).TotalMilliseconds);

                return savedRecord;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Backup operation failed");
                
                // Clean up partial backup file if it exists
                if (File.Exists(backupPath))
                {
                    try
                    {
                        File.Delete(backupPath);
                    }
                    catch (Exception deleteEx)
                    {
                        _logger.LogWarning(deleteEx, "Failed to delete partial backup file {BackupPath}", backupPath);
                    }
                }

                var failedRecord = new BackupRecord
                {
                    Id = Guid.NewGuid(),
                    StartedAt = startedAt,
                    CompletedAt = DateTime.UtcNow,
                    Status = BackupStatus.Failed,
                    ArtifactPath = null
                };

                // Save failed backup record to database
                var savedFailedRecord = await _backupRepository.SaveBackupRecordAsync(failedRecord);
                return savedFailedRecord;
            }
        }

        public string GetBackupDirectory()
        {
            var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            return Path.Combine(appDataPath, "Chronicae", "Backups");
        }

        private async Task<BackupData> CreateBackupDataAsync()
        {
            _logger.LogDebug("Collecting backup data from repositories");

            // Get all projects with their statistics
            var projects = await _projectRepository.GetAllAsync(includeStats: true);
            var projectList = new List<ProjectBackupData>();

            foreach (var project in projects)
            {
                var projectData = new ProjectBackupData
                {
                    Id = project.Id,
                    Name = project.Name,
                    NoteCount = project.NoteCount,
                    LastIndexedAt = project.LastIndexedAt,
                    Stats = project.Stats,
                    Notes = new List<NoteBackupData>()
                };

                // Get all notes for this project
                var notesResult = await _noteRepository.GetByProjectAsync(project.Id, limit: int.MaxValue);
                
                foreach (var note in notesResult.Items)
                {
                    var noteData = new NoteBackupData
                    {
                        Id = note.Id,
                        ProjectId = note.ProjectId,
                        Title = note.Title,
                        Content = note.Content,
                        Excerpt = note.Excerpt,
                        Tags = note.Tags,
                        CreatedAt = note.CreatedAt,
                        UpdatedAt = note.UpdatedAt,
                        Version = note.Version,
                        Versions = new List<NoteVersionBackupData>()
                    };

                    // Get all versions for this note
                    var versions = await _versionRepository.GetByNoteAsync(note.Id, limit: int.MaxValue);
                    
                    foreach (var version in versions)
                    {
                        var versionData = new NoteVersionBackupData
                        {
                            Id = version.Id,
                            NoteId = version.NoteId,
                            Title = version.Title,
                            Content = version.Content,
                            Excerpt = version.Excerpt,
                            CreatedAt = version.CreatedAt,
                            Version = version.Version
                        };
                        
                        noteData.Versions.Add(versionData);
                    }

                    projectData.Notes.Add(noteData);
                }

                projectList.Add(projectData);
            }

            return new BackupData
            {
                Version = "1.0",
                CreatedAt = DateTime.UtcNow,
                Projects = projectList
            };
        }

        private async Task CreateZipFileAsync(string zipPath, BackupData backupData)
        {
            _logger.LogDebug("Creating ZIP file at {ZipPath}", zipPath);

            using var fileStream = new FileStream(zipPath, FileMode.Create, FileAccess.Write);
            using var archive = new ZipArchive(fileStream, ZipArchiveMode.Create);

            // Add metadata file
            var metadataEntry = archive.CreateEntry("metadata.json");
            using (var metadataStream = metadataEntry.Open())
            {
                var metadata = new
                {
                    version = backupData.Version,
                    createdAt = backupData.CreatedAt,
                    projectCount = backupData.Projects.Count,
                    totalNotes = backupData.Projects.Sum(p => p.Notes.Count),
                    totalVersions = backupData.Projects.Sum(p => p.Notes.Sum(n => n.Versions.Count))
                };
                
                await JsonSerializer.SerializeAsync(metadataStream, metadata, JsonOptions);
            }

            // Add full backup data
            var dataEntry = archive.CreateEntry("backup.json");
            using (var dataStream = dataEntry.Open())
            {
                await JsonSerializer.SerializeAsync(dataStream, backupData, JsonOptions);
            }

            // Add individual project files for easier partial restoration
            foreach (var project in backupData.Projects)
            {
                var projectEntry = archive.CreateEntry($"projects/{project.Name}_{project.Id}.json");
                using var projectStream = projectEntry.Open();
                await JsonSerializer.SerializeAsync(projectStream, project, JsonOptions);
            }

            _logger.LogDebug("ZIP file created successfully");
        }
    }

    // Backup data transfer objects
    public class BackupData
    {
        public string Version { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public List<ProjectBackupData> Projects { get; set; } = new();
    }

    public class ProjectBackupData
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int NoteCount { get; set; }
        public DateTime? LastIndexedAt { get; set; }
        public ProjectStats? Stats { get; set; }
        public List<NoteBackupData> Notes { get; set; } = new();
    }

    public class NoteBackupData
    {
        public Guid Id { get; set; }
        public Guid ProjectId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string? Excerpt { get; set; }
        public List<string> Tags { get; set; } = new();
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int Version { get; set; }
        public List<NoteVersionBackupData> Versions { get; set; } = new();
    }

    public class NoteVersionBackupData
    {
        public Guid Id { get; set; }
        public Guid NoteId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string? Excerpt { get; set; }
        public DateTime CreatedAt { get; set; }
        public int Version { get; set; }
    }
}