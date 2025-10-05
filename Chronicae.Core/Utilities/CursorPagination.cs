using System;
using System.Globalization;
using System.Text;

namespace Chronicae.Core.Utilities
{
    /// <summary>
    /// Utility class for cursor-based pagination using Base64 encoding
    /// </summary>
    public static class CursorPagination
    {
        /// <summary>
        /// Encodes cursor information into a Base64 string
        /// </summary>
        /// <param name="updatedAt">Last updated timestamp</param>
        /// <param name="createdAt">Creation timestamp</param>
        /// <param name="id">Entity ID</param>
        /// <returns>Base64 encoded cursor string</returns>
        public static string EncodeCursor(DateTime updatedAt, DateTime createdAt, Guid id)
        {
            // Use ISO8601 format for dates to ensure consistent parsing
            var updatedAtIso = updatedAt.ToString("O", CultureInfo.InvariantCulture);
            var createdAtIso = createdAt.ToString("O", CultureInfo.InvariantCulture);
            
            var raw = $"{updatedAtIso}|{createdAtIso}|{id}";
            var bytes = Encoding.UTF8.GetBytes(raw);
            return Convert.ToBase64String(bytes);
        }
        
        /// <summary>
        /// Decodes a Base64 cursor string into its component parts
        /// </summary>
        /// <param name="cursor">Base64 encoded cursor string</param>
        /// <returns>Tuple of timestamps and ID if valid, null if invalid</returns>
        public static (DateTime UpdatedAt, DateTime CreatedAt, Guid Id)? DecodeCursor(string cursor)
        {
            if (string.IsNullOrWhiteSpace(cursor))
                return null;
                
            try
            {
                var bytes = Convert.FromBase64String(cursor);
                var raw = Encoding.UTF8.GetString(bytes);
                var parts = raw.Split('|');
                
                if (parts.Length != 3)
                    return null;
                
                // Parse ISO8601 dates with round-trip format
                var updatedAt = DateTime.Parse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
                var createdAt = DateTime.Parse(parts[1], CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
                var id = Guid.Parse(parts[2]);
                
                return (updatedAt, createdAt, id);
            }
            catch (Exception)
            {
                // Return null for any parsing errors (invalid Base64, invalid dates, invalid GUID)
                return null;
            }
        }
        
        /// <summary>
        /// Creates a cursor from a note entity
        /// </summary>
        /// <param name="note">Note entity</param>
        /// <returns>Encoded cursor string</returns>
        public static string CreateCursorFromNote(Core.Models.Note note)
        {
            return EncodeCursor(note.UpdatedAt, note.CreatedAt, note.Id);
        }
        
        /// <summary>
        /// Validates if a cursor string is properly formatted
        /// </summary>
        /// <param name="cursor">Cursor string to validate</param>
        /// <returns>True if valid, false otherwise</returns>
        public static bool IsValidCursor(string cursor)
        {
            return DecodeCursor(cursor) != null;
        }
    }
}