using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using TrayMe.Windows.Models;

namespace TrayMe.Windows.Views
{
    public partial class FilesView : UserControl
    {
        public FilesView()
        {
            InitializeComponent();
            DataContext = App.FilesManager;
            
            CopyFilesCheckBox.IsChecked = App.FilesManager.ShouldCopyFiles;
            RefreshList();

            // Subscribe to changes
            App.FilesManager.PropertyChanged += (s, e) => RefreshList();
        }

        private void RefreshList()
        {
            var manager = App.FilesManager;
            
            FilesList.ItemsSource = manager.FilteredFiles;
            
            bool hasFiles = manager.Files.Any();
            DropZone.Visibility = hasFiles ? Visibility.Collapsed : Visibility.Visible;
            FilesGrid.Visibility = hasFiles ? Visibility.Visible : Visibility.Collapsed;
            
            FileCountText.Text = $"{manager.Files.Count}/{manager.MaxFiles} files";
            
            // Update file icons/thumbnails in the list
            UpdateFileIcons();
        }

        private void UpdateFileIcons()
        {
            // This will be called after the ItemsControl updates
            Dispatcher.BeginInvoke(new Action(() =>
            {
                foreach (var item in FilesList.Items)
                {
                    if (item is FileItem file)
                    {
                        var container = FilesList.ItemContainerGenerator.ContainerFromItem(item) as ContentPresenter;
                        if (container != null)
                        {
                            var image = FindChild<Image>(container, "FileIcon");
                            if (image != null)
                            {
                                if (file.Thumbnail != null)
                                    image.Source = file.Thumbnail;
                                else if (file.Icon != null)
                                    image.Source = file.Icon;
                            }
                        }
                    }
                }
            }), System.Windows.Threading.DispatcherPriority.Loaded);
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            App.FilesManager.SearchText = SearchBox.Text;
            ClearSearchButton.Visibility = string.IsNullOrEmpty(SearchBox.Text) 
                ? Visibility.Collapsed 
                : Visibility.Visible;
        }

        private void ClearSearch_Click(object sender, RoutedEventArgs e)
        {
            SearchBox.Text = "";
        }

        private void UserControl_DragEnter(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
                DropZone.Tag = "Dragging";
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
            e.Handled = true;
        }

        private void UserControl_DragLeave(object sender, DragEventArgs e)
        {
            DropZone.Tag = null;
        }

        private void UserControl_Drop(object sender, DragEventArgs e)
        {
            DropZone.Tag = null;
            
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                var files = (string[])e.Data.GetData(DataFormats.FileDrop);
                if (files != null && files.Length > 0)
                {
                    App.FilesManager.AddFiles(files);
                }
            }
        }

        private void FileCard_MouseEnter(object sender, MouseEventArgs e)
        {
            if (sender is Border border)
            {
                border.Background = (Brush)FindResource("HoverBackground");
                var actionsPanel = FindChild<StackPanel>(border, "ActionsPanel");
                if (actionsPanel != null)
                    actionsPanel.Visibility = Visibility.Visible;
            }
        }

        private void FileCard_MouseLeave(object sender, MouseEventArgs e)
        {
            if (sender is Border border)
            {
                border.Background = (Brush)FindResource("CardBackground");
                var actionsPanel = FindChild<StackPanel>(border, "ActionsPanel");
                if (actionsPanel != null)
                    actionsPanel.Visibility = Visibility.Collapsed;
            }
        }

        private void FileCard_Click(object sender, MouseButtonEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is FileItem file)
            {
                App.FilesManager.OpenFile(file);
            }
        }

        private void FileCard_MouseMove(object sender, MouseEventArgs e)
        {
            if (e.LeftButton == MouseButtonState.Pressed && sender is FrameworkElement element)
            {
                if (element.DataContext is FileItem file)
                {
                    var dataObject = new DataObject(DataFormats.FileDrop, new[] { file.FilePath });
                    DragDrop.DoDragDrop(element, dataObject, DragDropEffects.Copy);
                }
            }
        }

        private void OpenFile_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var file = FindParentDataContext<FileItem>(element);
                if (file != null)
                    App.FilesManager.OpenFile(file);
            }
            e.Handled = true;
        }

        private void RevealFile_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var file = FindParentDataContext<FileItem>(element);
                if (file != null)
                    App.FilesManager.RevealInExplorer(file);
            }
            e.Handled = true;
        }

        private void CopyImage_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var file = FindParentDataContext<FileItem>(element);
                if (file != null)
                {
                    App.FilesManager.CopyImageToClipboard(file);
                    MessageBox.Show("Image copied to clipboard!", "Success", 
                        MessageBoxButton.OK, MessageBoxImage.Information);
                }
            }
            e.Handled = true;
        }

        private void DeleteFile_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var file = FindParentDataContext<FileItem>(element);
                if (file != null)
                    App.FilesManager.RemoveFile(file);
            }
            e.Handled = true;
        }

        private void CopyFiles_Changed(object sender, RoutedEventArgs e)
        {
            App.FilesManager.ShouldCopyFiles = CopyFilesCheckBox.IsChecked == true;
        }

        private void OpenStorage_Click(object sender, RoutedEventArgs e)
        {
            App.FilesManager.OpenStorageFolder();
        }

        private void SetLimit_Click(object sender, RoutedEventArgs e)
        {
            if (sender is MenuItem menuItem && int.TryParse(menuItem.Tag?.ToString(), out int limit))
            {
                if (limit < App.FilesManager.Files.Count)
                {
                    MessageBox.Show(
                        $"Cannot set limit to {limit}. You have {App.FilesManager.Files.Count} files.\nPlease remove some files first.",
                        "Cannot Reduce Limit",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning);
                    return;
                }
                App.FilesManager.MaxFiles = limit;
            }
        }

        private void RefreshStatus_Click(object sender, RoutedEventArgs e)
        {
            RefreshList();
        }

        private void ClearReferences_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Delete all file references?", "Confirm", 
                MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                App.FilesManager.ClearAllReferences();
            }
        }

        private void ClearStored_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Delete all stored files? This cannot be undone.", "Confirm", 
                MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                App.FilesManager.ClearAllStored();
            }
        }

        private void ClearAll_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Delete everything? This cannot be undone.", "Confirm", 
                MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                App.FilesManager.ClearAll();
            }
        }

        // Helper methods
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

        private T? FindParentDataContext<T>(DependencyObject child) where T : class
        {
            var parent = VisualTreeHelper.GetParent(child);
            while (parent != null)
            {
                if (parent is FrameworkElement element && element.DataContext is T context)
                    return context;
                parent = VisualTreeHelper.GetParent(parent);
            }
            return null;
        }
    }
}
