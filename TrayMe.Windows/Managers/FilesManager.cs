using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows.Media.Imaging;
using Newtonsoft.Json;
using TrayMe.Windows.Models;
using System.Drawing;
using System.Windows;
using System.Windows.Interop;

namespace TrayMe.Windows.Managers
{
    public class FilesManager : INotifyPropertyChanged
    {
        private const int AbsoluteMaxFileLimit = 100;
        
        private ObservableCollection<FileItem> _files = new();
        private string _searchText = string.Empty;
        private bool _isLoading;
        private bool _shouldCopyFiles;
        private int _maxFiles = 50;
        private System.Timers.Timer? _saveTimer;

        public ObservableCollection<FileItem> Files
        {
            get => _files;
            set { _files = value; OnPropertyChanged(); OnPropertyChanged(nameof(FilteredFiles)); }
        }

        public string SearchText
        {
            get => _searchText;
            set { _searchText = value; OnPropertyChanged(); OnPropertyChanged(nameof(FilteredFiles)); }
        }

        public bool IsLoading
        {
            get => _isLoading;
            set { _isLoading = value; OnPropertyChanged(); }
        }

        public bool ShouldCopyFiles
        {
            get => _shouldCopyFiles;
            set { _shouldCopyFiles = value; OnPropertyChanged(); SaveSettings(); }
        }

        public int MaxFiles
        {
            get => Math.Min(_maxFiles, AbsoluteMaxFileLimit);
            set { _maxFiles = Math.Min(value, AbsoluteMaxFileLimit); OnPropertyChanged(); SaveSettings(); }
        }

        public ObservableCollection<FileItem> FilteredFiles
        {
            get
            {
                if (string.IsNullOrWhiteSpace(SearchText))
                    return Files;
                    
                var filtered = Files.Where(f => 
                    f.Name.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
                return new ObservableCollection<FileItem>(filtered);
            }
        }

        public FilesManager()
        {
            LoadSettings();
            LoadFromDisk();
        }

        public string StorageFolder
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                var folder = Path.Combine(appData, "TrayMe", "StoredFiles");
                Directory.CreateDirectory(folder);
                return folder;
            }
        }

        private string ThumbnailCacheFolder
        {
            get
            {
                var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                var folder = Path.Combine(localAppData, "TrayMe", "Thumbnails");
                Directory.CreateDirectory(folder);
                return folder;
            }
        }

        public void AddFile(string filePath)
        {
            if (Files.Any(f => f.FilePath.Equals(filePath, StringComparison.OrdinalIgnoreCase)))
                return;

            string finalPath = filePath;
            bool isCopied = false;

            if (ShouldCopyFiles)
            {
                var copiedPath = CopyFileToStorage(filePath);
                if (copiedPath != null)
                {
                    finalPath = copiedPath;
                    isCopied = true;
                }
            }

            var newFile = new FileItem(finalPath, isCopied);
            LoadFileIcon(newFile);
            LoadFileThumbnail(newFile);

            Files.Insert(0, newFile);

            // Enforce limit
            while (Files.Count > MaxFiles)
            {
                var lastFile = Files.LastOrDefault();
                if (lastFile != null)
                    RemoveFile(lastFile);
            }

            OnPropertyChanged(nameof(FilteredFiles));
            DebouncedSave();
        }

        public void AddFiles(string[] filePaths)
        {
            var availableSlots = MaxFiles - Files.Count;
            if (filePaths.Length > availableSlots)
            {
                MessageBox.Show(
                    $"Cannot add {filePaths.Length} files. Only {availableSlots} slots available.",
                    "File Limit Reached",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
                return;
            }

            foreach (var path in filePaths)
            {
                // Check for duplicates
                bool isDuplicate = Files.Any(f =>
                {
                    var existingName = Path.GetFileName(f.FilePath);
                    var newName = Path.GetFileName(path);
                    return existingName.Equals(newName, StringComparison.OrdinalIgnoreCase) &&
                           f.IsCopied == ShouldCopyFiles;
                });

                if (!isDuplicate)
                {
                    string finalPath = path;
                    bool isCopied = false;

                    if (ShouldCopyFiles)
                    {
                        var copiedPath = CopyFileToStorage(path);
                        if (copiedPath != null)
                        {
                            finalPath = copiedPath;
                            isCopied = true;
                        }
                    }

                    var newFile = new FileItem(finalPath, isCopied);
                    LoadFileIcon(newFile);
                    LoadFileThumbnail(newFile);
                    Files.Insert(0, newFile);
                }
            }

            OnPropertyChanged(nameof(FilteredFiles));
            DebouncedSave();
        }

        private string? CopyFileToStorage(string sourcePath)
        {
            try
            {
                var fileName = Path.GetFileName(sourcePath);
                var destPath = Path.Combine(StorageFolder, fileName);
                int counter = 1;

                while (File.Exists(destPath))
                {
                    var nameWithoutExt = Path.GetFileNameWithoutExtension(sourcePath);
                    var ext = Path.GetExtension(sourcePath);
                    destPath = Path.Combine(StorageFolder, $"{nameWithoutExt} ({counter}){ext}");
                    counter++;

                    if (counter > 1000)
                        return null;
                }

                File.Copy(sourcePath, destPath);
                return destPath;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to copy file: {ex.Message}");
                return null;
            }
        }

        public void RemoveFile(FileItem file)
        {
            // Delete stored file
            if (file.IsCopied && File.Exists(file.FilePath))
            {
                try
                {
                    File.Delete(file.FilePath);
                }
                catch { }
            }

            // Delete cached thumbnail
            DeleteCachedThumbnail(file.FilePath);

            Files.Remove(file);
            OnPropertyChanged(nameof(FilteredFiles));
            DebouncedSave();
        }

        public void ClearAll()
        {
            foreach (var file in Files.ToList())
            {
                if (file.IsCopied && File.Exists(file.FilePath))
                {
                    try { File.Delete(file.FilePath); } catch { }
                }
                DeleteCachedThumbnail(file.FilePath);
            }
            Files.Clear();
            OnPropertyChanged(nameof(FilteredFiles));
            SaveToDisk();
        }

        public void ClearAllReferences()
        {
            var references = Files.Where(f => !f.IsCopied).ToList();
            foreach (var file in references)
            {
                DeleteCachedThumbnail(file.FilePath);
                Files.Remove(file);
            }
            OnPropertyChanged(nameof(FilteredFiles));
            SaveToDisk();
        }

        public void ClearAllStored()
        {
            var stored = Files.Where(f => f.IsCopied).ToList();
            foreach (var file in stored)
            {
                if (File.Exists(file.FilePath))
                {
                    try { File.Delete(file.FilePath); } catch { }
                }
                DeleteCachedThumbnail(file.FilePath);
                Files.Remove(file);
            }
            OnPropertyChanged(nameof(FilteredFiles));
            SaveToDisk();
        }

        public void OpenFile(FileItem file)
        {
            if (File.Exists(file.FilePath))
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = file.FilePath,
                    UseShellExecute = true
                });
            }
        }

        public void RevealInExplorer(FileItem file)
        {
            if (File.Exists(file.FilePath))
            {
                System.Diagnostics.Process.Start("explorer.exe", $"/select,\"{file.FilePath}\"");
            }
        }

        public void OpenStorageFolder()
        {
            System.Diagnostics.Process.Start("explorer.exe", StorageFolder);
        }

        public void CopyImageToClipboard(FileItem file)
        {
            if (!FileItem.IsImageFile(file.FileType) || !File.Exists(file.FilePath))
                return;

            try
            {
                var image = new BitmapImage(new Uri(file.FilePath));
                System.Windows.Clipboard.SetImage(image);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to copy image: {ex.Message}");
            }
        }

        private void LoadFileIcon(FileItem file)
        {
            try
            {
                if (!File.Exists(file.FilePath))
                    return;

                using var icon = System.Drawing.Icon.ExtractAssociatedIcon(file.FilePath);
                if (icon != null)
                {
                    file.Icon = Imaging.CreateBitmapSourceFromHIcon(
                        icon.Handle,
                        Int32Rect.Empty,
                        BitmapSizeOptions.FromEmptyOptions());
                }
            }
            catch { }
        }

        private void LoadFileThumbnail(FileItem file)
        {
            if (!FileItem.IsImageFile(file.FileType))
                return;

            // Try to load from cache first
            var cachedPath = GetThumbnailCachePath(file.FilePath);
            if (File.Exists(cachedPath))
            {
                try
                {
                    var bitmap = new BitmapImage();
                    bitmap.BeginInit();
                    bitmap.CacheOption = BitmapCacheOption.OnLoad;
                    bitmap.UriSource = new Uri(cachedPath);
                    bitmap.EndInit();
                    bitmap.Freeze();
                    file.Thumbnail = bitmap;
                    return;
                }
                catch { }
            }

            // Generate thumbnail in background
            System.Threading.Tasks.Task.Run(() =>
            {
                try
                {
                    var thumbnail = GenerateThumbnail(file.FilePath);
                    if (thumbnail != null)
                    {
                        // Save to cache
                        SaveThumbnailToCache(file.FilePath, thumbnail);

                        Application.Current?.Dispatcher.Invoke(() =>
                        {
                            thumbnail.Freeze();
                            file.Thumbnail = thumbnail;
                        });
                    }
                }
                catch { }
            });
        }

        private BitmapImage? GenerateThumbnail(string filePath)
        {
            try
            {
                var bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.DecodePixelWidth = 160;
                bitmap.UriSource = new Uri(filePath);
                bitmap.EndInit();
                return bitmap;
            }
            catch
            {
                return null;
            }
        }

        private string GetThumbnailCachePath(string filePath)
        {
            using var md5 = System.Security.Cryptography.MD5.Create();
            var hash = md5.ComputeHash(System.Text.Encoding.UTF8.GetBytes(filePath));
            var hashString = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
            return Path.Combine(ThumbnailCacheFolder, $"{hashString}.png");
        }

        private void SaveThumbnailToCache(string filePath, BitmapImage thumbnail)
        {
            try
            {
                var cachePath = GetThumbnailCachePath(filePath);
                var encoder = new PngBitmapEncoder();
                encoder.Frames.Add(BitmapFrame.Create(thumbnail));
                using var stream = new FileStream(cachePath, FileMode.Create);
                encoder.Save(stream);
            }
            catch { }
        }

        private void DeleteCachedThumbnail(string filePath)
        {
            try
            {
                var cachePath = GetThumbnailCachePath(filePath);
                if (File.Exists(cachePath))
                    File.Delete(cachePath);
            }
            catch { }
        }

        // Debounced save
        private void DebouncedSave()
        {
            _saveTimer?.Stop();
            _saveTimer = new System.Timers.Timer(500);
            _saveTimer.Elapsed += (s, e) =>
            {
                _saveTimer?.Stop();
                Application.Current?.Dispatcher.Invoke(SaveToDisk);
            };
            _saveTimer.AutoReset = false;
            _saveTimer.Start();
        }

        // Persistence
        private string SavePath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                var folder = Path.Combine(appData, "TrayMe");
                Directory.CreateDirectory(folder);
                return Path.Combine(folder, "files.json");
            }
        }

        private string SettingsPath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                var folder = Path.Combine(appData, "TrayMe");
                Directory.CreateDirectory(folder);
                return Path.Combine(folder, "files_settings.json");
            }
        }

        public void SaveToDisk()
        {
            try
            {
                var json = JsonConvert.SerializeObject(Files, Formatting.Indented, new JsonSerializerSettings
                {
                    DateFormatHandling = DateFormatHandling.IsoDateFormat
                });
                File.WriteAllText(SavePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save files: {ex.Message}");
            }
        }

        private void LoadFromDisk()
        {
            IsLoading = true;
            try
            {
                if (!File.Exists(SavePath))
                {
                    IsLoading = false;
                    return;
                }

                var json = File.ReadAllText(SavePath);
                var files = JsonConvert.DeserializeObject<ObservableCollection<FileItem>>(json);

                if (files != null)
                {
                    Files = files;
                    
                    // Load icons and thumbnails for each file
                    foreach (var file in Files)
                    {
                        LoadFileIcon(file);
                        LoadFileThumbnail(file);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load files: {ex.Message}");
            }
            finally
            {
                IsLoading = false;
            }
        }

        private void SaveSettings()
        {
            try
            {
                var settings = new { ShouldCopyFiles, MaxFiles };
                var json = JsonConvert.SerializeObject(settings);
                File.WriteAllText(SettingsPath, json);
            }
            catch { }
        }

        private void LoadSettings()
        {
            try
            {
                if (!File.Exists(SettingsPath))
                    return;

                var json = File.ReadAllText(SettingsPath);
                var settings = JsonConvert.DeserializeAnonymousType(json, new { ShouldCopyFiles = false, MaxFiles = 50 });
                if (settings != null)
                {
                    _shouldCopyFiles = settings.ShouldCopyFiles;
                    _maxFiles = settings.MaxFiles;
                }
            }
            catch { }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
