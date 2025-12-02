using System.Windows;
using System.Windows.Controls;

namespace TrayMe.Windows.Views
{
    public partial class SettingsWindow : Window
    {
        private bool _isLoading = true;

        public SettingsWindow()
        {
            InitializeComponent();
            LoadSettings();
            _isLoading = false;
        }

        private void LoadSettings()
        {
            var settings = App.AppSettings;
            
            MouseActivationCheckBox.IsChecked = settings.EnableMouseActivation;
            HotkeyActivationCheckBox.IsChecked = settings.EnableHotkeyActivation;
            PanelWidthBox.Text = settings.PanelWidth.ToString();
            PanelHeightBox.Text = settings.PanelHeight.ToString();
            
            IgnorePasswordManagersCheckBox.IsChecked = settings.IgnorePasswordManagers;
            ClipboardEnabledCheckBox.IsChecked = settings.ClipboardEnabled;
            
            FilesEnabledCheckBox.IsChecked = settings.FilesEnabled;
            NotesEnabledCheckBox.IsChecked = settings.NotesEnabled;
            
            // Set combo box selections
            SetComboBoxSelection(MaxHistoryCombo, settings.ClipboardMaxHistory.ToString());
            SetComboBoxSelection(MaxFilesCombo, settings.FilesMaxStorage.ToString());
        }

        private void SetComboBoxSelection(ComboBox comboBox, string value)
        {
            foreach (ComboBoxItem item in comboBox.Items)
            {
                if (item.Content?.ToString() == value)
                {
                    comboBox.SelectedItem = item;
                    break;
                }
            }
        }

        private void Setting_Changed(object sender, RoutedEventArgs e)
        {
            if (_isLoading) return;
            
            var settings = App.AppSettings;
            
            settings.EnableMouseActivation = MouseActivationCheckBox.IsChecked == true;
            settings.EnableHotkeyActivation = HotkeyActivationCheckBox.IsChecked == true;
            settings.IgnorePasswordManagers = IgnorePasswordManagersCheckBox.IsChecked == true;
            settings.ClipboardEnabled = ClipboardEnabledCheckBox.IsChecked == true;
            settings.FilesEnabled = FilesEnabledCheckBox.IsChecked == true;
            settings.NotesEnabled = NotesEnabledCheckBox.IsChecked == true;
            
            // Update clipboard manager
            App.ClipboardManager.IgnorePasswordManagers = settings.IgnorePasswordManagers;
        }

        private void PanelSize_Changed(object sender, TextChangedEventArgs e)
        {
            if (_isLoading) return;
            
            if (double.TryParse(PanelWidthBox.Text, out double width) && width > 0)
                App.AppSettings.PanelWidth = width;
                
            if (double.TryParse(PanelHeightBox.Text, out double height) && height > 0)
                App.AppSettings.PanelHeight = height;
        }

        private void MaxHistory_Changed(object sender, SelectionChangedEventArgs e)
        {
            if (_isLoading) return;
            
            if (MaxHistoryCombo.SelectedItem is ComboBoxItem item && 
                int.TryParse(item.Content?.ToString(), out int value))
            {
                App.AppSettings.ClipboardMaxHistory = value;
                App.ClipboardManager.MaxHistorySize = value;
            }
        }

        private void MaxFiles_Changed(object sender, SelectionChangedEventArgs e)
        {
            if (_isLoading) return;
            
            if (MaxFilesCombo.SelectedItem is ComboBoxItem item && 
                int.TryParse(item.Content?.ToString(), out int value))
            {
                App.AppSettings.FilesMaxStorage = value;
                App.FilesManager.MaxFiles = value;
            }
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
