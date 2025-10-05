using System;

namespace Chronicae.Core.Utilities
{
    /// <summary>
    /// Utility class for generating search result snippets
    /// </summary>
    public static class SnippetGenerator
    {
        private const int DefaultSnippetLength = 160;
        
        /// <summary>
        /// Generates a snippet from content, highlighting the search term context
        /// </summary>
        /// <param name="content">The full content to extract snippet from</param>
        /// <param name="searchTerm">The search term to find and highlight context for</param>
        /// <param name="excerptFallback">Fallback excerpt if search term is not found</param>
        /// <param name="maxLength">Maximum length of the snippet (default: 160)</param>
        /// <returns>Generated snippet with context around the search term</returns>
        public static string GenerateSnippet(string content, string searchTerm, string? excerptFallback = null, int maxLength = DefaultSnippetLength)
        {
            if (string.IsNullOrWhiteSpace(content))
                return excerptFallback ?? string.Empty;
            
            if (string.IsNullOrWhiteSpace(searchTerm))
                return excerptFallback ?? TruncateContent(content, maxLength);
            
            var lowerContent = content.ToLower();
            var lowerSearchTerm = searchTerm.Trim().ToLower();
            var index = lowerContent.IndexOf(lowerSearchTerm, StringComparison.Ordinal);
            
            // If search term not found, return excerpt fallback or truncated content
            if (index == -1)
            {
                return excerptFallback ?? TruncateContent(content, maxLength);
            }
            
            // Calculate start position to center the search term in the snippet
            var halfLength = maxLength / 2;
            var start = Math.Max(0, index - halfLength);
            
            // Adjust start to avoid cutting words if possible
            start = FindWordBoundary(content, start, true);
            
            // Calculate end position
            var end = Math.Min(content.Length, start + maxLength);
            end = FindWordBoundary(content, end, false);
            
            // Extract the snippet
            var snippet = content.Substring(start, end - start);
            
            // Add ellipsis if we're not at the beginning/end
            if (start > 0)
                snippet = "..." + snippet;
            if (end < content.Length)
                snippet = snippet + "...";
            
            return snippet.Trim();
        }
        
        /// <summary>
        /// Truncates content to specified length, trying to break at word boundaries
        /// </summary>
        /// <param name="content">Content to truncate</param>
        /// <param name="maxLength">Maximum length</param>
        /// <returns>Truncated content</returns>
        private static string TruncateContent(string content, int maxLength)
        {
            if (content.Length <= maxLength)
                return content;
            
            var truncated = content.Substring(0, maxLength);
            var lastSpace = truncated.LastIndexOf(' ');
            
            // If there's a space reasonably close to the end, break there
            if (lastSpace > maxLength * 0.75)
            {
                truncated = truncated.Substring(0, lastSpace);
            }
            
            return truncated + "...";
        }
        
        /// <summary>
        /// Finds a word boundary near the specified position
        /// </summary>
        /// <param name="content">The content to search in</param>
        /// <param name="position">The target position</param>
        /// <param name="searchBackward">Whether to search backward (true) or forward (false)</param>
        /// <returns>Position of word boundary, or original position if no suitable boundary found</returns>
        private static int FindWordBoundary(string content, int position, bool searchBackward)
        {
            if (position <= 0 || position >= content.Length)
                return position;
            
            var searchRange = Math.Min(20, content.Length / 10); // Search within 20 chars or 10% of content
            var start = searchBackward ? Math.Max(0, position - searchRange) : position;
            var end = searchBackward ? position : Math.Min(content.Length, position + searchRange);
            
            if (searchBackward)
            {
                // Search backward for space or punctuation
                for (int i = position; i >= start; i--)
                {
                    if (char.IsWhiteSpace(content[i]) || char.IsPunctuation(content[i]))
                    {
                        return i + 1; // Return position after the delimiter
                    }
                }
            }
            else
            {
                // Search forward for space or punctuation
                for (int i = position; i < end; i++)
                {
                    if (char.IsWhiteSpace(content[i]) || char.IsPunctuation(content[i]))
                    {
                        return i;
                    }
                }
            }
            
            return position; // Return original position if no boundary found
        }
    }
}