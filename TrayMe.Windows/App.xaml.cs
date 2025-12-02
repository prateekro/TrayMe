using System.Windows;
using NHotkey;
using NHotkey.Wpf;
using System.Windows.Input;
using Hardcodet.Wpf.TaskbarNotification;
using TrayMe.Windows.Managers;
using System.Drawing;
using System.Windows.Media.Imaging;
using System.Reflection;
using TrayMe.Windows.Views;
using System.IO;

namespace TrayMe.Windows
{
    public partial class App : Application
    {
        private TaskbarIcon? _notifyIcon;
        private MainWindow? _mainWindow;
        
        public static ClipboardManager ClipboardManager { get; private set; } = null!;
        public static FilesManager FilesManager { get; private set; } = null!;
        public static NotesManager NotesManager { get; private set; } = null!;
        public static AppSettings AppSettings { get; private set; } = null!;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            // Initialize managers
            AppSettings = new AppSettings();
            ClipboardManager = new ClipboardManager();
            FilesManager = new FilesManager();
            NotesManager = new NotesManager();
            
            // Create system tray icon
            CreateNotifyIcon();
            
            // Register global hotkey (Ctrl+Shift+U)
            RegisterHotkey();
            
            // Create main window but don't show it yet
            _mainWindow = new MainWindow();
            _mainWindow.Hide();
        }

        private void CreateNotifyIcon()
        {
            _notifyIcon = new TaskbarIcon
            {
                ToolTipText = "TrayMe - Click to show panel",
            };
            
            // Use default icon or create one programmatically
            try
            {
                // Try to load icon from resources if available
                string iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Assets", "icon.ico");
                if (File.Exists(iconPath))
                {
                    _notifyIcon.Icon = new Icon(iconPath);
                }
                else
                {
                    // Create a simple default icon
                    _notifyIcon.Icon = SystemIcons.Application;
                }
            }
            catch
            {
                _notifyIcon.Icon = SystemIcons.Application;
            }
            
            _notifyIcon.TrayMouseDoubleClick += NotifyIcon_TrayMouseDoubleClick;
            
            // Create context menu
            var contextMenu = new System.Windows.Controls.ContextMenu();
            
            var showItem = new System.Windows.Controls.MenuItem { Header = "Show Panel" };
            showItem.Click += (s, e) => TogglePanel();
            contextMenu.Items.Add(showItem);
            
            var settingsItem = new System.Windows.Controls.MenuItem { Header = "Settings" };
            settingsItem.Click += (s, e) => ShowSettings();
            contextMenu.Items.Add(settingsItem);
            
            contextMenu.Items.Add(new System.Windows.Controls.Separator());
            
            var exitItem = new System.Windows.Controls.MenuItem { Header = "Exit" };
            exitItem.Click += (s, e) => ExitApplication();
            contextMenu.Items.Add(exitItem);
            
            _notifyIcon.ContextMenu = contextMenu;
        }

        private void RegisterHotkey()
        {
            try
            {
                HotkeyManager.Current.AddOrReplace("ShowPanel", Key.U, ModifierKeys.Control | ModifierKeys.Shift, OnHotkeyPressed);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to register hotkey: {ex.Message}");
            }
        }

        private void OnHotkeyPressed(object? sender, HotkeyEventArgs e)
        {
            TogglePanel();
            e.Handled = true;
        }

        private void NotifyIcon_TrayMouseDoubleClick(object sender, RoutedEventArgs e)
        {
            TogglePanel();
        }

        public void TogglePanel()
        {
            if (_mainWindow == null) return;
            
            if (_mainWindow.IsVisible)
            {
                _mainWindow.HidePanel();
            }
            else
            {
                _mainWindow.ShowPanel();
            }
        }

        public void ShowWithFilesTab()
        {
            if (_mainWindow == null) return;
            _mainWindow.ShowPanelWithFilesTab();
        }

        private void ShowSettings()
        {
            var settingsWindow = new SettingsWindow();
            settingsWindow.ShowDialog();
        }

        private void ExitApplication()
        {
            // Save all data
            ClipboardManager?.SaveToDisk();
            FilesManager?.SaveToDisk();
            NotesManager?.SaveToDisk();
            
            _notifyIcon?.Dispose();
            Shutdown();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            _notifyIcon?.Dispose();
            base.OnExit(e);
        }
    }
}
