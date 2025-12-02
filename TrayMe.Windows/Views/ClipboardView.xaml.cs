using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using TrayMe.Windows.Models;

namespace TrayMe.Windows.Views
{
    public partial class ClipboardView : UserControl
    {
        public ClipboardView()
        {
            InitializeComponent();
            DataContext = App.ClipboardManager;
            RefreshList();

            // Subscribe to changes
            App.ClipboardManager.PropertyChanged += (s, e) => RefreshList();
        }

        private void RefreshList()
        {
            var manager = App.ClipboardManager;
            
            ClipboardList.ItemsSource = manager.FilteredItems;
            FavoritesList.ItemsSource = manager.Favorites;
            
            FavoritesSection.Visibility = manager.Favorites.Any() && string.IsNullOrWhiteSpace(manager.SearchText) 
                ? Visibility.Visible 
                : Visibility.Collapsed;
            
            ItemCountText.Text = $"{manager.Items.Count} items";
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            App.ClipboardManager.SearchText = SearchBox.Text;
            ClearSearchButton.Visibility = string.IsNullOrEmpty(SearchBox.Text) 
                ? Visibility.Collapsed 
                : Visibility.Visible;
        }

        private void ClearSearch_Click(object sender, RoutedEventArgs e)
        {
            SearchBox.Text = "";
        }

        private void ClipboardItem_MouseEnter(object sender, MouseEventArgs e)
        {
            if (sender is Border border)
            {
                border.Background = (Brush)FindResource("HoverBackground");
                var actionsPanel = FindChild<StackPanel>(border, "ActionsPanel");
                if (actionsPanel != null)
                    actionsPanel.Visibility = Visibility.Visible;
            }
        }

        private void ClipboardItem_MouseLeave(object sender, MouseEventArgs e)
        {
            if (sender is Border border)
            {
                border.Background = Brushes.Transparent;
                var actionsPanel = FindChild<StackPanel>(border, "ActionsPanel");
                if (actionsPanel != null)
                    actionsPanel.Visibility = Visibility.Collapsed;
            }
        }

        private void ClipboardItem_Click(object sender, MouseButtonEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is ClipboardItem item)
            {
                App.ClipboardManager.CopyToClipboard(item);
            }
        }

        private void FavoriteCard_Click(object sender, MouseButtonEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is ClipboardItem item)
            {
                App.ClipboardManager.CopyToClipboard(item);
            }
        }

        private void ToggleFavorite_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var item = FindParentDataContext<ClipboardItem>(element);
                if (item != null)
                {
                    App.ClipboardManager.ToggleFavorite(item);
                }
            }
            e.Handled = true;
        }

        private void CopyItem_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var item = FindParentDataContext<ClipboardItem>(element);
                if (item != null)
                {
                    App.ClipboardManager.CopyToClipboard(item);
                }
            }
            e.Handled = true;
        }

        private void DeleteItem_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element)
            {
                var item = FindParentDataContext<ClipboardItem>(element);
                if (item != null)
                {
                    App.ClipboardManager.DeleteItem(item);
                }
            }
            e.Handled = true;
        }

        private void ClearHistory_Click(object sender, RoutedEventArgs e)
        {
            App.ClipboardManager.ClearHistory();
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
