using System;
using System.Text.RegularExpressions;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace TrayMe.Windows.Models
{
    public class ClipboardItem
    {
        public Guid Id { get; set; }
        public string Content { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; }
        public bool IsFavorite { get; set; }
        
        [JsonConverter(typeof(StringEnumConverter))]
        public ClipboardType Type { get; set; }

        public ClipboardItem()
        {
            Id = Guid.NewGuid();
            Timestamp = DateTime.Now;
        }

        public ClipboardItem(string content, ClipboardType type = ClipboardType.Text, bool isFavorite = false)
        {
            Id = Guid.NewGuid();
            Content = content;
            Timestamp = DateTime.Now;
            IsFavorite = isFavorite;
            Type = type;
        }

        public string DisplayContent
        {
            get
            {
                const int maxLength = 100;
                if (Content.Length > maxLength)
                {
                    return Content.Substring(0, maxLength) + "...";
                }
                return Content;
            }
        }

        public string TimeAgo
        {
            get
            {
                var timeSpan = DateTime.Now - Timestamp;
                
                if (timeSpan.TotalSeconds < 60)
                    return "just now";
                if (timeSpan.TotalMinutes < 60)
                    return $"{(int)timeSpan.TotalMinutes}m ago";
                if (timeSpan.TotalHours < 24)
                    return $"{(int)timeSpan.TotalHours}h ago";
                if (timeSpan.TotalDays < 7)
                    return $"{(int)timeSpan.TotalDays}d ago";
                    
                return Timestamp.ToString("MMM d");
            }
        }

        public static ClipboardType DetermineType(string content)
        {
            // Check if URL
            if (Uri.TryCreate(content, UriKind.Absolute, out var uri) &&
                (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps))
            {
                return ClipboardType.Url;
            }

            // Check if code (simple heuristic)
            if (content.Contains("{") || 
                content.Contains("function") || 
                content.Contains("class ") || 
                content.Contains("import ") ||
                content.Contains("public ") ||
                content.Contains("private ") ||
                content.Contains("void ") ||
                Regex.IsMatch(content, @"^\s*(if|for|while|switch|try)\s*\(", RegexOptions.Multiline))
            {
                return ClipboardType.Code;
            }

            return ClipboardType.Text;
        }
    }

    public enum ClipboardType
    {
        Text,
        Url,
        Code,
        Image
    }
}
