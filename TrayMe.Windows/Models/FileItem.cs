using System;
using System.IO;
using System.Windows.Media.Imaging;
using Newtonsoft.Json;

namespace TrayMe.Windows.Models
{
    public class FileItem
    {
        public Guid Id { get; set; }
        public string FilePath { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string FileType { get; set; } = string.Empty;
        public long Size { get; set; }
        public DateTime AddedDate { get; set; }
        public bool IsCopied { get; set; }

        [JsonIgnore]
        public BitmapSource? Thumbnail { get; set; }

        [JsonIgnore]
        public BitmapSource? Icon { get; set; }

        public FileItem()
        {
            Id = Guid.NewGuid();
            AddedDate = DateTime.Now;
        }

        public FileItem(string filePath, bool isCopied = false)
        {
            Id = Guid.NewGuid();
            FilePath = filePath;
            Name = Path.GetFileName(filePath);
            FileType = Path.GetExtension(filePath).TrimStart('.').ToLowerInvariant();
            AddedDate = DateTime.Now;
            IsCopied = isCopied;

            try
            {
                var fileInfo = new FileInfo(filePath);
                Size = fileInfo.Length;
            }
            catch
            {
                Size = 0;
            }
        }

        public string FormattedSize
        {
            get
            {
                string[] sizes = { "B", "KB", "MB", "GB", "TB" };
                double len = Size;
                int order = 0;
                while (len >= 1024 && order < sizes.Length - 1)
                {
                    order++;
                    len = len / 1024;
                }
                return $"{len:0.##} {sizes[order]}";
            }
        }

        public bool FileExists()
        {
            return File.Exists(FilePath);
        }

        public static bool IsImageFile(string fileType)
        {
            var imageExtensions = new[] { "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "ico" };
            return Array.Exists(imageExtensions, ext => 
                ext.Equals(fileType, StringComparison.OrdinalIgnoreCase));
        }
    }
}
