using System;
using System.Windows;
using System.Windows.Forms;
using System.Windows.Media.Animation;
using TrayMe.Windows.Views;

namespace TrayMe.Windows
{
    public partial class MainWindow : Window
    {
        private bool _isAnimating;
        private string _selectedTab = "clipboard";

        public MainWindow()
        {
            InitializeComponent();
            PositionWindow();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            PositionWindow();
            UpdateTabHighlights();
        }

        private void PositionWindow()
        {
            // Position at top center of primary screen
            var screen = Screen.PrimaryScreen;
            if (screen == null) return;

            Width = App.AppSettings.PanelWidth;
            Height = App.AppSettings.PanelHeight;

            Left = (screen.WorkingArea.Width - Width) / 2;
            Top = -Height; // Start hidden above screen
        }

        public void ShowPanel()
        {
            if (_isAnimating) return;
            _isAnimating = true;

            PositionWindow();
            Show();
            Activate();

            // Slide down animation
            var animation = new DoubleAnimation
            {
                From = -Height,
                To = 0,
                Duration = TimeSpan.FromMilliseconds(300),
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            };

            animation.Completed += (s, e) => _isAnimating = false;
            BeginAnimation(TopProperty, animation);
        }

        public void ShowPanelWithFilesTab()
        {
            _selectedTab = "files";
            UpdateTabHighlights();
            ShowPanel();
        }

        public void HidePanel()
        {
            if (_isAnimating) return;
            _isAnimating = true;

            // Slide up animation
            var animation = new DoubleAnimation
            {
                From = 0,
                To = -Height,
                Duration = TimeSpan.FromMilliseconds(250),
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseIn }
            };

            animation.Completed += (s, e) =>
            {
                _isAnimating = false;
                Hide();
            };

            BeginAnimation(TopProperty, animation);
        }

        private void Window_Deactivated(object sender, EventArgs e)
        {
            // Hide when clicking outside (unless animating)
            if (!_isAnimating && IsVisible)
            {
                HidePanel();
            }
        }

        private void ClipboardTab_Click(object sender, RoutedEventArgs e)
        {
            _selectedTab = "clipboard";
            UpdateTabHighlights();
        }

        private void FilesTab_Click(object sender, RoutedEventArgs e)
        {
            _selectedTab = "files";
            UpdateTabHighlights();
        }

        private void NotesTab_Click(object sender, RoutedEventArgs e)
        {
            _selectedTab = "notes";
            UpdateTabHighlights();
        }

        private void UpdateTabHighlights()
        {
            ClipboardTabButton.Tag = _selectedTab == "clipboard" ? "Selected" : null;
            FilesTabButton.Tag = _selectedTab == "files" ? "Selected" : null;
            NotesTabButton.Tag = _selectedTab == "notes" ? "Selected" : null;

            // Update panel backgrounds
            ClipboardPanel.Background = _selectedTab == "clipboard" 
                ? (System.Windows.Media.Brush)FindResource("SelectedPanelBackground") 
                : System.Windows.Media.Brushes.Transparent;
            FilesPanel.Background = _selectedTab == "files" 
                ? (System.Windows.Media.Brush)FindResource("SelectedPanelBackground") 
                : System.Windows.Media.Brushes.Transparent;
            NotesPanel.Background = _selectedTab == "notes" 
                ? (System.Windows.Media.Brush)FindResource("SelectedPanelBackground") 
                : System.Windows.Media.Brushes.Transparent;
        }

        private void Settings_Click(object sender, RoutedEventArgs e)
        {
            HidePanel();
            var settingsWindow = new SettingsWindow();
            settingsWindow.ShowDialog();
        }
    }
}
