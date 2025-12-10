use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Manages application windows and their states
pub struct WindowManager {
    trayed_windows: HashMap<String, TrayedWindow>,
}

impl WindowManager {
    pub fn new() -> Self {
        Self {
            trayed_windows: HashMap::new(),
        }
    }

    /// Add a window to the tray
    pub fn add_to_tray(&mut self, window: TrayedWindow) -> String {
        let id = window.id.clone();
        self.trayed_windows.insert(id.clone(), window);
        id
    }

    /// Remove a window from the tray
    pub fn remove_from_tray(&mut self, id: &str) -> Option<TrayedWindow> {
        self.trayed_windows.remove(id)
    }

    /// Get all trayed windows
    pub fn list_trayed_windows(&self) -> Vec<&TrayedWindow> {
        self.trayed_windows.values().collect()
    }

    /// Get a specific trayed window
    pub fn get_trayed_window(&self, id: &str) -> Option<&TrayedWindow> {
        self.trayed_windows.get(id)
    }

    /// Update window metadata
    pub fn update_window(&mut self, id: &str, update_fn: impl FnOnce(&mut TrayedWindow)) -> bool {
        if let Some(window) = self.trayed_windows.get_mut(id) {
            update_fn(window);
            true
        } else {
            false
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrayedWindow {
    pub id: String,
    pub title: String,
    pub app_name: String,
    pub process_id: Option<u32>,
    pub workspace: Option<String>,
    pub preview_data: Option<Vec<u8>>,
    pub created_at: i64,
    pub metadata: HashMap<String, String>,
}

impl TrayedWindow {
    pub fn new(title: String, app_name: String) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            title,
            app_name,
            process_id: None,
            workspace: None,
            preview_data: None,
            created_at: chrono::Utc::now().timestamp(),
            metadata: HashMap::new(),
        }
    }
}
