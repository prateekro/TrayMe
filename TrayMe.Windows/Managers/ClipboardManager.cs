using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Timers;
using System.Windows;
using Newtonsoft.Json;
using TrayMe.Windows.Models;
using Timer = System.Timers.Timer;

namespace TrayMe.Windows.Managers
{
    public class ClipboardManager : INotifyPropertyChanged
    {
        private ObservableCollection<ClipboardItem> _items = new();
        private ObservableCollection<ClipboardItem> _favorites = new();
        private string _searchText = string.Empty;
        private string? _lastClipboardContent;
        private Timer? _clipboardTimer;
        
        // Password manager process names to ignore
        private readonly string[] _passwordManagerProcesses = 
        {
            "1password",
            "lastpass",
            "bitwarden",
            "dashlane",
            "keepass",
            "roboform"
        };

        public int MaxHistorySize { get; set; } = 100;
        public bool IgnorePasswordManagers { get; set; } = true;

        public ObservableCollection<ClipboardItem> Items
        {
            get => _items;
            set { _items = value; OnPropertyChanged(); OnPropertyChanged(nameof(FilteredItems)); }
        }

        public ObservableCollection<ClipboardItem> Favorites
        {
            get => _favorites;
            set { _favorites = value; OnPropertyChanged(); }
        }

        public string SearchText
        {
            get => _searchText;
            set { _searchText = value; OnPropertyChanged(); OnPropertyChanged(nameof(FilteredItems)); }
        }

        public ObservableCollection<ClipboardItem> FilteredItems
        {
            get
            {
                if (string.IsNullOrWhiteSpace(SearchText))
                    return Items;
                    
                var filtered = Items.Where(i => 
                    i.Content.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
                return new ObservableCollection<ClipboardItem>(filtered);
            }
        }

        public ClipboardManager()
        {
            LoadFromDisk();
            StartMonitoring();
        }

        public void StartMonitoring()
        {
            _clipboardTimer = new Timer(500); // Poll every 500ms
            _clipboardTimer.Elapsed += CheckClipboard;
            _clipboardTimer.AutoReset = true;
            _clipboardTimer.Start();
        }

        public void StopMonitoring()
        {
            _clipboardTimer?.Stop();
            _clipboardTimer?.Dispose();
        }

        private void CheckClipboard(object? sender, ElapsedEventArgs e)
        {
            try
            {
                Application.Current?.Dispatcher.Invoke(() =>
                {
                    if (!System.Windows.Clipboard.ContainsText())
                        return;

                    string? text = null;
                    try
                    {
                        text = System.Windows.Clipboard.GetText();
                    }
                    catch
                    {
                        // Clipboard may be locked by another process
                        return;
                    }

                    if (string.IsNullOrEmpty(text) || text == _lastClipboardContent)
                        return;

                    // Check if from password manager
                    if (IgnorePasswordManagers && IsFromPasswordManager())
                        return;

                    _lastClipboardContent = text;
                    AddItem(text);
                });
            }
            catch
            {
                // Ignore clipboard access errors
            }
        }

        private bool IsFromPasswordManager()
        {
            try
            {
                var foregroundWindow = GetForegroundWindow();
                if (foregroundWindow == IntPtr.Zero)
                    return false;

                GetWindowThreadProcessId(foregroundWindow, out uint processId);
                var process = System.Diagnostics.Process.GetProcessById((int)processId);
                var processName = process.ProcessName.ToLowerInvariant();

                return _passwordManagerProcesses.Any(pm => processName.Contains(pm));
            }
            catch
            {
                return false;
            }
        }

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        public void AddItem(string content)
        {
            // Don't add duplicates of the most recent item
            if (Items.FirstOrDefault()?.Content == content)
                return;

            var type = ClipboardItem.DetermineType(content);
            var newItem = new ClipboardItem(content, type);

            Items.Insert(0, newItem);

            // Limit history size
            while (Items.Count > MaxHistorySize)
            {
                var lastNonFavorite = Items.LastOrDefault(i => !i.IsFavorite);
                if (lastNonFavorite != null)
                    Items.Remove(lastNonFavorite);
                else
                    break;
            }

            OnPropertyChanged(nameof(FilteredItems));
            SaveToDisk();
        }

        public void CopyToClipboard(ClipboardItem item)
        {
            try
            {
                _lastClipboardContent = item.Content; // Prevent re-adding
                System.Windows.Clipboard.SetText(item.Content);
            }
            catch
            {
                // Clipboard may be locked
            }
        }

        public void ToggleFavorite(ClipboardItem item)
        {
            var existingItem = Items.FirstOrDefault(i => i.Id == item.Id);
            if (existingItem == null) return;

            existingItem.IsFavorite = !existingItem.IsFavorite;

            if (existingItem.IsFavorite)
            {
                if (!Favorites.Any(f => f.Id == existingItem.Id))
                    Favorites.Add(existingItem);
            }
            else
            {
                var favToRemove = Favorites.FirstOrDefault(f => f.Id == existingItem.Id);
                if (favToRemove != null)
                    Favorites.Remove(favToRemove);
            }

            OnPropertyChanged(nameof(Items));
            OnPropertyChanged(nameof(Favorites));
            SaveToDisk();
        }

        public void DeleteItem(ClipboardItem item)
        {
            Items.Remove(item);
            var favItem = Favorites.FirstOrDefault(f => f.Id == item.Id);
            if (favItem != null)
                Favorites.Remove(favItem);
            
            OnPropertyChanged(nameof(FilteredItems));
            SaveToDisk();
        }

        public void UpdateItemContent(ClipboardItem item, string newContent)
        {
            var existingItem = Items.FirstOrDefault(i => i.Id == item.Id);
            if (existingItem == null) return;

            var index = Items.IndexOf(existingItem);
            var updatedItem = new ClipboardItem
            {
                Id = existingItem.Id,
                Content = newContent,
                Timestamp = existingItem.Timestamp,
                IsFavorite = existingItem.IsFavorite,
                Type = ClipboardItem.DetermineType(newContent)
            };

            Items[index] = updatedItem;

            // Update in favorites too
            var favItem = Favorites.FirstOrDefault(f => f.Id == item.Id);
            if (favItem != null)
            {
                var favIndex = Favorites.IndexOf(favItem);
                Favorites[favIndex] = updatedItem;
            }

            OnPropertyChanged(nameof(FilteredItems));
            SaveToDisk();
        }

        public void ClearHistory()
        {
            // Remove only non-favorite items
            var nonFavorites = Items.Where(i => !i.IsFavorite).ToList();
            foreach (var item in nonFavorites)
            {
                Items.Remove(item);
            }
            
            OnPropertyChanged(nameof(FilteredItems));
            SaveToDisk();
        }

        // Persistence
        private string SavePath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                var folder = Path.Combine(appData, "TrayMe");
                Directory.CreateDirectory(folder);
                return Path.Combine(folder, "clipboard.json");
            }
        }

        public void SaveToDisk()
        {
            try
            {
                var json = JsonConvert.SerializeObject(Items, Formatting.Indented, new JsonSerializerSettings
                {
                    DateFormatHandling = DateFormatHandling.IsoDateFormat
                });
                File.WriteAllText(SavePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save clipboard: {ex.Message}");
            }
        }

        private void LoadFromDisk()
        {
            try
            {
                if (!File.Exists(SavePath))
                    return;

                var json = File.ReadAllText(SavePath);
                var items = JsonConvert.DeserializeObject<ObservableCollection<ClipboardItem>>(json);
                
                if (items != null)
                {
                    Items = items;
                    Favorites = new ObservableCollection<ClipboardItem>(items.Where(i => i.IsFavorite));
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load clipboard: {ex.Message}");
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
