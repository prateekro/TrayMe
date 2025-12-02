using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using TrayMe.Windows.Models;

namespace TrayMe.Windows.Views
{
    public partial class NotesView : UserControl
    {
        private DispatcherTimer? _saveTimer;
        private bool _isUpdating;

        public NotesView()
        {
            InitializeComponent();
            DataContext = App.NotesManager;
            
            RefreshList();
            UpdateEditor();

            // Subscribe to changes
            App.NotesManager.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(App.NotesManager.SelectedNote))
                    UpdateEditor();
                else
                    RefreshList();
            };

            // Setup auto-save timer
            _saveTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
            _saveTimer.Tick += (s, e) =>
            {
                _saveTimer.Stop();
                SaveCurrentNote();
            };
        }

        private void RefreshList()
        {
            var manager = App.NotesManager;
            NotesList.ItemsSource = manager.FilteredNotes;
            
            // Highlight selected note
            Dispatcher.BeginInvoke(new Action(() =>
            {
                foreach (var item in NotesList.Items)
                {
                    if (item is Note note)
                    {
                        var container = NotesList.ItemContainerGenerator.ContainerFromItem(item) as ContentPresenter;
                        if (container != null)
                        {
                            var border = FindChild<Border>(container, "NoteBorder");
                            if (border != null)
                            {
                                border.Background = note.Id == manager.SelectedNote?.Id
                                    ? (Brush)FindResource("SelectedBackground")
                                    : Brushes.Transparent;
                            }
                        }
                    }
                }
            }), DispatcherPriority.Loaded);
        }

        private void UpdateEditor()
        {
            _isUpdating = true;
            
            var note = App.NotesManager.SelectedNote;
            
            if (note == null)
            {
                EmptyState.Visibility = Visibility.Visible;
                TitleBox.Visibility = Visibility.Collapsed;
                ContentBox.Visibility = Visibility.Collapsed;
                return;
            }
            
            EmptyState.Visibility = Visibility.Collapsed;
            TitleBox.Visibility = Visibility.Visible;
            ContentBox.Visibility = Visibility.Visible;
            
            TitleBox.Text = note.Title;
            ContentBox.Text = note.Content;
            
            UpdatePinButton(note.IsPinned);
            ModifiedText.Text = $"Modified: {note.ModifiedTimeAgo}";
            
            _isUpdating = false;
        }

        private void UpdatePinButton(bool isPinned)
        {
            PinButtonIcon.Text = isPinned ? "📌" : "📍";
            PinButtonText.Text = isPinned ? "Pinned" : "Pin";
            PinButton.Foreground = isPinned 
                ? (Brush)FindResource("AccentBrush") 
                : (Brush)FindResource("SecondaryTextBrush");
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            App.NotesManager.SearchText = SearchBox.Text;
        }

        private void NewNote_Click(object sender, RoutedEventArgs e)
        {
            App.NotesManager.CreateNote();
            ContentBox.Focus();
        }

        private void NoteItem_Click(object sender, MouseButtonEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is Note note)
            {
                // Save current note before switching
                SaveCurrentNote();
                App.NotesManager.SelectedNote = note;
            }
        }

        private void TitleBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_isUpdating) return;
            ScheduleSave();
        }

        private void ContentBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_isUpdating) return;
            ScheduleSave();
        }

        private void ScheduleSave()
        {
            _saveTimer?.Stop();
            _saveTimer?.Start();
        }

        private void SaveCurrentNote()
        {
            var note = App.NotesManager.SelectedNote;
            if (note == null) return;
            
            App.NotesManager.UpdateNote(note, TitleBox.Text, ContentBox.Text);
            ModifiedText.Text = "Modified: just now";
        }

        private void TogglePin_Click(object sender, RoutedEventArgs e)
        {
            var note = App.NotesManager.SelectedNote;
            if (note != null)
            {
                App.NotesManager.TogglePin(note);
                UpdatePinButton(note.IsPinned);
            }
        }

        private void DeleteNote_Click(object sender, RoutedEventArgs e)
        {
            var note = App.NotesManager.SelectedNote;
            if (note != null)
            {
                if (MessageBox.Show("Delete this note?", "Confirm", 
                    MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    App.NotesManager.DeleteNote(note);
                }
            }
        }

        // Helper method
        private T? FindChild<T>(DependencyObject parent, string name) where T : FrameworkElement
        {
            for (int i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is T typedChild && typedChild.Name == name)
                    return typedChild;
                
                var result = FindChild<T>(child, name);
                if (result != null)
                    return result;
            }
            return null;
        }
    }
}
