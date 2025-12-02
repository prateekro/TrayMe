using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using Newtonsoft.Json;

namespace TrayMe.Windows.Managers
{
    public class AppSettings : INotifyPropertyChanged
    {
        private bool _enableMouseActivation = true;
        private bool _enableHotkeyActivation = true;
        private string _hotkeyModifiers = "Ctrl+Shift";
        private string _hotkeyKey = "U";
        private int _clipboardMaxHistory = 100;
        private bool _ignorePasswordManagers = true;
        private bool _clipboardEnabled = true;
        private int _filesMaxStorage = 50;
        private bool _filesEnabled = true;
        private bool _notesEnabled = true;
        private double _panelWidth = 900;
        private double _panelHeight = 400;
        private string _defaultTab = "clipboard";
        private bool _isLoading;

        public bool EnableMouseActivation
        {
            get => _enableMouseActivation;
            set { _enableMouseActivation = value; OnPropertyChanged(); Save(); }
        }

        public bool EnableHotkeyActivation
        {
            get => _enableHotkeyActivation;
            set { _enableHotkeyActivation = value; OnPropertyChanged(); Save(); }
        }

        public string HotkeyModifiers
        {
            get => _hotkeyModifiers;
            set { _hotkeyModifiers = value; OnPropertyChanged(); Save(); }
        }

        public string HotkeyKey
        {
            get => _hotkeyKey;
            set { _hotkeyKey = value; OnPropertyChanged(); Save(); }
        }

        public int ClipboardMaxHistory
        {
            get => _clipboardMaxHistory;
            set { _clipboardMaxHistory = value; OnPropertyChanged(); Save(); }
        }

        public bool IgnorePasswordManagers
        {
            get => _ignorePasswordManagers;
            set { _ignorePasswordManagers = value; OnPropertyChanged(); Save(); }
        }

        public bool ClipboardEnabled
        {
            get => _clipboardEnabled;
            set { _clipboardEnabled = value; OnPropertyChanged(); Save(); }
        }

        public int FilesMaxStorage
        {
            get => _filesMaxStorage;
            set { _filesMaxStorage = value; OnPropertyChanged(); Save(); }
        }

        public bool FilesEnabled
        {
            get => _filesEnabled;
            set { _filesEnabled = value; OnPropertyChanged(); Save(); }
        }

        public bool NotesEnabled
        {
            get => _notesEnabled;
            set { _notesEnabled = value; OnPropertyChanged(); Save(); }
        }

        public double PanelWidth
        {
            get => _panelWidth;
            set { _panelWidth = value; OnPropertyChanged(); Save(); }
        }

        public double PanelHeight
        {
            get => _panelHeight;
            set { _panelHeight = value; OnPropertyChanged(); Save(); }
        }

        public string DefaultTab
        {
            get => _defaultTab;
            set { _defaultTab = value; OnPropertyChanged(); Save(); }
        }

        public AppSettings()
        {
            _isLoading = true;
            Load();
            _isLoading = false;
        }

        private string SettingsPath
        {
            get
            {
                var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                var folder = Path.Combine(appData, "TrayMe");
                Directory.CreateDirectory(folder);
                return Path.Combine(folder, "settings.json");
            }
        }

        private void Save()
        {
            if (_isLoading) return;

            try
            {
                var settings = new
                {
                    EnableMouseActivation,
                    EnableHotkeyActivation,
                    HotkeyModifiers,
                    HotkeyKey,
                    ClipboardMaxHistory,
                    IgnorePasswordManagers,
                    ClipboardEnabled,
                    FilesMaxStorage,
                    FilesEnabled,
                    NotesEnabled,
                    PanelWidth,
                    PanelHeight,
                    DefaultTab
                };

                var json = JsonConvert.SerializeObject(settings, Formatting.Indented);
                File.WriteAllText(SettingsPath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save settings: {ex.Message}");
            }
        }

        private void Load()
        {
            try
            {
                if (!File.Exists(SettingsPath))
                    return;

                var json = File.ReadAllText(SettingsPath);
                var settings = JsonConvert.DeserializeAnonymousType(json, new
                {
                    EnableMouseActivation = true,
                    EnableHotkeyActivation = true,
                    HotkeyModifiers = "Ctrl+Shift",
                    HotkeyKey = "U",
                    ClipboardMaxHistory = 100,
                    IgnorePasswordManagers = true,
                    ClipboardEnabled = true,
                    FilesMaxStorage = 50,
                    FilesEnabled = true,
                    NotesEnabled = true,
                    PanelWidth = 900.0,
                    PanelHeight = 400.0,
                    DefaultTab = "clipboard"
                });

                if (settings != null)
                {
                    _enableMouseActivation = settings.EnableMouseActivation;
                    _enableHotkeyActivation = settings.EnableHotkeyActivation;
                    _hotkeyModifiers = settings.HotkeyModifiers;
                    _hotkeyKey = settings.HotkeyKey;
                    _clipboardMaxHistory = settings.ClipboardMaxHistory;
                    _ignorePasswordManagers = settings.IgnorePasswordManagers;
                    _clipboardEnabled = settings.ClipboardEnabled;
                    _filesMaxStorage = settings.FilesMaxStorage;
                    _filesEnabled = settings.FilesEnabled;
                    _notesEnabled = settings.NotesEnabled;
                    _panelWidth = settings.PanelWidth;
                    _panelHeight = settings.PanelHeight;
                    _defaultTab = settings.DefaultTab;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to load settings: {ex.Message}");
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }
}
