#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_window_manager_add_and_list() {
        let mut manager = WindowManager::new();
        
        let window1 = TrayedWindow::new("Test Window 1".to_string(), "App1".to_string());
        let id1 = window1.id.clone();
        manager.add_to_tray(window1);
        
        let window2 = TrayedWindow::new("Test Window 2".to_string(), "App2".to_string());
        let id2 = window2.id.clone();
        manager.add_to_tray(window2);
        
        let windows = manager.list_trayed_windows();
        assert_eq!(windows.len(), 2);
        assert!(manager.get_trayed_window(&id1).is_some());
        assert!(manager.get_trayed_window(&id2).is_some());
    }

    #[test]
    fn test_window_manager_remove() {
        let mut manager = WindowManager::new();
        
        let window = TrayedWindow::new("Test Window".to_string(), "App".to_string());
        let id = window.id.clone();
        manager.add_to_tray(window);
        
        assert!(manager.get_trayed_window(&id).is_some());
        
        let removed = manager.remove_from_tray(&id);
        assert!(removed.is_some());
        assert!(manager.get_trayed_window(&id).is_none());
    }

    #[test]
    fn test_window_manager_update() {
        let mut manager = WindowManager::new();
        
        let window = TrayedWindow::new("Test Window".to_string(), "App".to_string());
        let id = window.id.clone();
        manager.add_to_tray(window);
        
        let updated = manager.update_window(&id, |w| {
            w.title = "Updated Title".to_string();
            w.workspace = Some("Workspace 1".to_string());
        });
        
        assert!(updated);
        
        let window = manager.get_trayed_window(&id).unwrap();
        assert_eq!(window.title, "Updated Title");
        assert_eq!(window.workspace, Some("Workspace 1".to_string()));
    }

    #[test]
    fn test_trayed_window_creation() {
        let window = TrayedWindow::new("My Window".to_string(), "MyApp".to_string());
        
        assert!(!window.id.is_empty());
        assert_eq!(window.title, "My Window");
        assert_eq!(window.app_name, "MyApp");
        assert!(window.process_id.is_none());
        assert!(window.workspace.is_none());
        assert!(window.preview_data.is_none());
        assert!(window.created_at > 0);
        assert!(window.metadata.is_empty());
    }
}
