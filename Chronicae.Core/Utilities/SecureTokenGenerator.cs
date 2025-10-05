using System.Security.Cryptography;
using System.Text;

namespace Chronicae.Core.Utilities;

/// <summary>
/// Utility class for generating secure authentication tokens
/// </summary>
public static class SecureTokenGenerator
{
    /// <summary>
    /// Generates a cryptographically secure random token
    /// </summary>
    /// <returns>A Base64 URL-safe encoded token string</returns>
    public static string GenerateToken()
    {
        // Generate 32 bytes of random data
        byte[] tokenBytes = new byte[32];
        using (var rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(tokenBytes);
        }

        // Convert to Base64 URL-safe encoding
        return ToBase64UrlSafe(tokenBytes);
    }

    /// <summary>
    /// Converts byte array to Base64 URL-safe string
    /// </summary>
    /// <param name="bytes">Byte array to encode</param>
    /// <returns>Base64 URL-safe encoded string</returns>
    private static string ToBase64UrlSafe(byte[] bytes)
    {
        // Convert to standard Base64
        string base64 = Convert.ToBase64String(bytes);
        
        // Make it URL-safe by replacing characters
        return base64
            .Replace('+', '-')  // Replace + with -
            .Replace('/', '_')  // Replace / with _
            .TrimEnd('=');      // Remove padding
    }

    /// <summary>
    /// Validates if a token has the expected format and length
    /// </summary>
    /// <param name="token">Token to validate</param>
    /// <returns>True if token appears to be valid format</returns>
    public static bool IsValidTokenFormat(string? token)
    {
        if (string.IsNullOrEmpty(token))
            return false;

        // Check if it contains only valid Base64 URL-safe characters
        foreach (char c in token)
        {
            if (!IsBase64UrlSafeChar(c))
                return false;
        }

        // Check approximate length (32 bytes = ~43 characters in Base64)
        return token.Length >= 40 && token.Length <= 50;
    }

    /// <summary>
    /// Checks if character is valid for Base64 URL-safe encoding
    /// </summary>
    private static bool IsBase64UrlSafeChar(char c)
    {
        return (c >= 'A' && c <= 'Z') ||
               (c >= 'a' && c <= 'z') ||
               (c >= '0' && c <= '9') ||
               c == '-' || c == '_';
    }
}