using System;
using System.Linq;
using Newtonsoft.Json;

namespace TrayMe.Windows.Models
{
    public class Note
    {
        public Guid Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public DateTime CreatedDate { get; set; }
        public DateTime ModifiedDate { get; set; }
        public bool IsPinned { get; set; }

        public Note()
        {
            Id = Guid.NewGuid();
            CreatedDate = DateTime.Now;
            ModifiedDate = DateTime.Now;
        }

        public Note(string title = "", string content = "", bool isPinned = false)
        {
            Id = Guid.NewGuid();
            Title = title;
            Content = content;
            CreatedDate = DateTime.Now;
            ModifiedDate = DateTime.Now;
            IsPinned = isPinned;
        }

        public void Update(string? title = null, string? content = null)
        {
            if (title != null)
                Title = title;
            if (content != null)
                Content = content;
            ModifiedDate = DateTime.Now;
        }

        [JsonIgnore]
        public string DisplayTitle
        {
            get
            {
                if (!string.IsNullOrEmpty(Title))
                    return Title;
                    
                // Extract first line from content
                var firstLine = Content.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
                if (string.IsNullOrEmpty(firstLine))
                    return "Untitled Note";
                    
                return firstLine.Length > 30 ? firstLine.Substring(0, 30) : firstLine;
            }
        }

        [JsonIgnore]
        public string Preview
        {
            get
            {
                const int maxLength = 100;
                if (Content.Length > maxLength)
                    return Content.Substring(0, maxLength) + "...";
                return Content;
            }
        }

        [JsonIgnore]
        public string ModifiedTimeAgo
        {
            get
            {
                var timeSpan = DateTime.Now - ModifiedDate;
                
                if (timeSpan.TotalSeconds < 60)
                    return "just now";
                if (timeSpan.TotalMinutes < 60)
                    return $"{(int)timeSpan.TotalMinutes}m ago";
                if (timeSpan.TotalHours < 24)
                    return $"{(int)timeSpan.TotalHours}h ago";
                if (timeSpan.TotalDays < 7)
                    return $"{(int)timeSpan.TotalDays}d ago";
                    
                return ModifiedDate.ToString("MMM d");
            }
        }
    }
}
