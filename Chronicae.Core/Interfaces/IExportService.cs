using System;
using System.Threading.Tasks;
using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces
{
    public interface IExportService
    {
        /// <summary>
        /// Exports a note to the specified format
        /// </summary>
        /// <param name="note">The note to export</param>
        /// <param name="format">Export format (md, pdf, txt)</param>
        /// <param name="outputPath">Output file path</param>
        /// <returns>Path to the exported file</returns>
        Task<string> ExportNoteAsync(Note note, string format, string outputPath);
        
        /// <summary>
        /// Exports a note version to the specified format
        /// </summary>
        /// <param name="version">The note version to export</param>
        /// <param name="format">Export format (md, pdf, txt)</param>
        /// <param name="outputPath">Output file path</param>
        /// <returns>Path to the exported file</returns>
        Task<string> ExportNoteVersionAsync(NoteVersion version, string format, string outputPath);
        
        /// <summary>
        /// Exports a project to the specified format
        /// </summary>
        /// <param name="projectId">The project ID to export</param>
        /// <param name="format">Export format (zip, json)</param>
        /// <param name="outputPath">Output file path</param>
        /// <returns>Path to the exported file</returns>
        Task<string> ExportProjectAsync(Guid projectId, string format, string outputPath);
        
        /// <summary>
        /// Gets the default export directory
        /// </summary>
        /// <returns>Full path to the export directory</returns>
        string GetExportDirectory();
    }
}