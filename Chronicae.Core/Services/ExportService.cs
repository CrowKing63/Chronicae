using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Markdig;
using DinkToPdf;
using DinkToPdf.Contracts;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;

namespace Chronicae.Core.Services
{
    public class ExportService : IExportService
    {
        private readonly IProjectRepository _projectRepository;
        private readonly INoteRepository _noteRepository;
        private readonly IVersionRepository _versionRepository;
        private readonly IConverter _pdfConverter;
        private readonly ILogger<ExportService> _logger;
        
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true,
            DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
        };

        public ExportService(
            IProjectRepository projectRepository,
            INoteRepository noteRepository,
            IVersionRepository versionRepository,
            IConverter pdfConverter,
            ILogger<ExportService> logger)
        {
            _projectRepository = projectRepository;
            _noteRepository = noteRepository;
            _versionRepository = versionRepository;
            _pdfConverter = pdfConverter;
            _logger = logger;
        }

        public async Task<string> ExportNoteAsync(Note note, string format, string outputPath)
        {
            _logger.LogInformation("Exporting note {NoteId} to format {Format}", note.Id, format);

            var content = PrepareNoteContent(note.Title, note.Content, note.Tags, note.CreatedAt, note.UpdatedAt);
            
            return format.ToLowerInvariant() switch
            {
                "md" => await ExportToMarkdownAsync(content, outputPath),
                "pdf" => await ExportToPdfAsync(content, outputPath),
                "txt" => await ExportToTextAsync(content, outputPath),
                _ => throw new ArgumentException($"Unsupported export format: {format}")
            };
        }

        public async Task<string> ExportNoteVersionAsync(NoteVersion version, string format, string outputPath)
        {
            _logger.LogInformation("Exporting note version {VersionId} to format {Format}", version.Id, format);

            var content = PrepareNoteContent(version.Title, version.Content, new List<string>(), version.CreatedAt, version.CreatedAt);
            
            return format.ToLowerInvariant() switch
            {
                "md" => await ExportToMarkdownAsync(content, outputPath),
                "pdf" => await ExportToPdfAsync(content, outputPath),
                "txt" => await ExportToTextAsync(content, outputPath),
                _ => throw new ArgumentException($"Unsupported export format: {format}")
            };
        }

        public async Task<string> ExportProjectAsync(Guid projectId, string format, string outputPath)
        {
            _logger.LogInformation("Exporting project {ProjectId} to format {Format}", projectId, format);

            return format.ToLowerInvariant() switch
            {
                "zip" => await ExportProjectToZipAsync(projectId, outputPath),
                "json" => await ExportProjectToJsonAsync(projectId, outputPath),
                _ => throw new ArgumentException($"Unsupported export format: {format}")
            };
        }

        public string GetExportDirectory()
        {
            var documentsPath = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            return Path.Combine(documentsPath, "Chronicae", "Exports");
        }

        private string PrepareNoteContent(string title, string content, List<string> tags, DateTime createdAt, DateTime updatedAt)
        {
            var sb = new StringBuilder();
            
            // Add title
            sb.AppendLine($"# {title}");
            sb.AppendLine();
            
            // Add metadata
            sb.AppendLine("## Metadata");
            sb.AppendLine($"- **Created:** {createdAt:yyyy-MM-dd HH:mm:ss} UTC");
            sb.AppendLine($"- **Updated:** {updatedAt:yyyy-MM-dd HH:mm:ss} UTC");
            
            if (tags.Count > 0)
            {
                sb.AppendLine($"- **Tags:** {string.Join(", ", tags)}");
            }
            
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            
            // Add content
            sb.AppendLine(content);
            
            return sb.ToString();
        }

        private async Task<string> ExportToMarkdownAsync(string content, string outputPath)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
            await File.WriteAllTextAsync(outputPath, content, Encoding.UTF8);
            
            _logger.LogDebug("Exported to Markdown: {OutputPath}", outputPath);
            return outputPath;
        }

        private async Task<string> ExportToTextAsync(string content, string outputPath)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
            
            // Convert Markdown to plain text by removing Markdown syntax
            var plainText = ConvertMarkdownToPlainText(content);
            await File.WriteAllTextAsync(outputPath, plainText, Encoding.UTF8);
            
            _logger.LogDebug("Exported to Text: {OutputPath}", outputPath);
            return outputPath;
        }

        private async Task<string> ExportToPdfAsync(string content, string outputPath)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
            
            try
            {
                // Convert Markdown to HTML
                var pipeline = new MarkdownPipelineBuilder()
                    .UseAdvancedExtensions()
                    .Build();
                
                var html = Markdown.ToHtml(content, pipeline);
                
                // Create complete HTML document
                var htmlDocument = CreateHtmlDocument(html);
                
                // Convert HTML to PDF
                var doc = new HtmlToPdfDocument()
                {
                    GlobalSettings = {
                        ColorMode = ColorMode.Color,
                        Orientation = Orientation.Portrait,
                        PaperSize = PaperKind.A4,
                        Margins = new MarginSettings { Top = 10, Bottom = 10, Left = 10, Right = 10 }
                    },
                    Objects = {
                        new ObjectSettings() {
                            PagesCount = true,
                            HtmlContent = htmlDocument,
                            WebSettings = { DefaultEncoding = "utf-8" }
                        }
                    }
                };
                
                var pdfBytes = _pdfConverter.Convert(doc);
                await File.WriteAllBytesAsync(outputPath, pdfBytes);
                
                _logger.LogDebug("Exported to PDF: {OutputPath}", outputPath);
                return outputPath;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to export to PDF");
                
                // Fallback to HTML export if PDF fails
                var htmlPath = Path.ChangeExtension(outputPath, ".html");
                var pipeline = new MarkdownPipelineBuilder().UseAdvancedExtensions().Build();
                var html = Markdown.ToHtml(content, pipeline);
                var htmlDocument = CreateHtmlDocument(html);
                
                await File.WriteAllTextAsync(htmlPath, htmlDocument, Encoding.UTF8);
                
                _logger.LogWarning("PDF export failed, exported to HTML instead: {HtmlPath}", htmlPath);
                return htmlPath;
            }
        }

        private async Task<string> ExportProjectToZipAsync(Guid projectId, string outputPath)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
            
            var project = await _projectRepository.GetByIdAsync(projectId, includeStats: true);
            if (project == null)
            {
                throw new ArgumentException($"Project not found: {projectId}");
            }

            using var fileStream = new FileStream(outputPath, FileMode.Create, FileAccess.Write);
            using var archive = new ZipArchive(fileStream, ZipArchiveMode.Create);

            // Add project metadata
            var metadataEntry = archive.CreateEntry("project.json");
            using (var metadataStream = metadataEntry.Open())
            {
                await JsonSerializer.SerializeAsync(metadataStream, project, JsonOptions);
            }

            // Get all notes for the project
            var notesResult = await _noteRepository.GetByProjectAsync(projectId, limit: int.MaxValue);
            
            // Add notes as individual files
            foreach (var note in notesResult.Items)
            {
                // Add note as Markdown
                var noteContent = PrepareNoteContent(note.Title, note.Content, note.Tags, note.CreatedAt, note.UpdatedAt);
                var noteEntry = archive.CreateEntry($"notes/{SanitizeFileName(note.Title)}.md");
                using var noteStream = noteEntry.Open();
                using var writer = new StreamWriter(noteStream, Encoding.UTF8);
                await writer.WriteAsync(noteContent);
                
                // Add note metadata as JSON
                var noteJsonEntry = archive.CreateEntry($"notes/{SanitizeFileName(note.Title)}.json");
                using var noteJsonStream = noteJsonEntry.Open();
                await JsonSerializer.SerializeAsync(noteJsonStream, note, JsonOptions);
                
                // Add versions if any
                var versions = await _versionRepository.GetByNoteAsync(note.Id, limit: int.MaxValue);
                if (versions.Any())
                {
                    var versionsEntry = archive.CreateEntry($"notes/{SanitizeFileName(note.Title)}_versions.json");
                    using var versionsStream = versionsEntry.Open();
                    await JsonSerializer.SerializeAsync(versionsStream, versions, JsonOptions);
                }
            }

            _logger.LogDebug("Exported project to ZIP: {OutputPath}", outputPath);
            return outputPath;
        }

        private async Task<string> ExportProjectToJsonAsync(Guid projectId, string outputPath)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
            
            var project = await _projectRepository.GetByIdAsync(projectId, includeStats: true);
            if (project == null)
            {
                throw new ArgumentException($"Project not found: {projectId}");
            }

            // Get all notes with versions
            var notesResult = await _noteRepository.GetByProjectAsync(projectId, limit: int.MaxValue);
            var notesWithVersions = new List<object>();
            
            foreach (var note in notesResult.Items)
            {
                var versions = await _versionRepository.GetByNoteAsync(note.Id, limit: int.MaxValue);
                notesWithVersions.Add(new
                {
                    note.Id,
                    note.ProjectId,
                    note.Title,
                    note.Content,
                    note.Excerpt,
                    note.Tags,
                    note.CreatedAt,
                    note.UpdatedAt,
                    note.Version,
                    Versions = versions
                });
            }

            var exportData = new
            {
                Project = project,
                Notes = notesWithVersions,
                ExportedAt = DateTime.UtcNow
            };

            await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(exportData, JsonOptions), Encoding.UTF8);
            
            _logger.LogDebug("Exported project to JSON: {OutputPath}", outputPath);
            return outputPath;
        }

        private string ConvertMarkdownToPlainText(string markdown)
        {
            // Simple Markdown to plain text conversion
            // Remove headers
            var text = System.Text.RegularExpressions.Regex.Replace(markdown, @"^#{1,6}\s+", "", System.Text.RegularExpressions.RegexOptions.Multiline);
            
            // Remove bold/italic
            text = System.Text.RegularExpressions.Regex.Replace(text, @"\*\*(.*?)\*\*", "$1");
            text = System.Text.RegularExpressions.Regex.Replace(text, @"\*(.*?)\*", "$1");
            text = System.Text.RegularExpressions.Regex.Replace(text, @"__(.*?)__", "$1");
            text = System.Text.RegularExpressions.Regex.Replace(text, @"_(.*?)_", "$1");
            
            // Remove links
            text = System.Text.RegularExpressions.Regex.Replace(text, @"\[([^\]]+)\]\([^\)]+\)", "$1");
            
            // Remove code blocks
            text = System.Text.RegularExpressions.Regex.Replace(text, @"```[\s\S]*?```", "");
            text = System.Text.RegularExpressions.Regex.Replace(text, @"`([^`]+)`", "$1");
            
            // Remove horizontal rules
            text = System.Text.RegularExpressions.Regex.Replace(text, @"^---+$", "", System.Text.RegularExpressions.RegexOptions.Multiline);
            
            return text.Trim();
        }

        private string CreateHtmlDocument(string bodyHtml)
        {
            return $@"<!DOCTYPE html>
<html>
<head>
    <meta charset=""utf-8"">
    <title>Chronicae Export</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }}
        h1, h2, h3, h4, h5, h6 {{
            color: #2c3e50;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
        }}
        code {{
            background-color: #f4f4f4;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }}
        pre {{
            background-color: #f4f4f4;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }}
        blockquote {{
            border-left: 4px solid #ddd;
            margin: 0;
            padding-left: 20px;
            color: #666;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }}
        th {{
            background-color: #f2f2f2;
        }}
    </style>
</head>
<body>
{bodyHtml}
</body>
</html>";
        }

        private string SanitizeFileName(string fileName)
        {
            var invalidChars = Path.GetInvalidFileNameChars();
            var sanitized = new StringBuilder();
            
            foreach (var c in fileName)
            {
                if (invalidChars.Contains(c))
                {
                    sanitized.Append('_');
                }
                else
                {
                    sanitized.Append(c);
                }
            }
            
            return sanitized.ToString().Trim();
        }
    }
}