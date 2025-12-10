use std::sync::Arc;
use tokio::sync::RwLock;
use anyhow::Result;
use tauri::AppHandle;

use crate::managers::{
    storage_manager::StorageManager,
    window_manager::WindowManager,
};

/// Global application state
pub struct AppState {
    pub app_handle: AppHandle,
    pub storage_manager: Arc<RwLock<StorageManager>>,
    pub window_manager: Arc<RwLock<WindowManager>>,
}

impl AppState {
    pub fn new(app_handle: AppHandle) -> Result<Self> {
        let storage_manager = Arc::new(RwLock::new(StorageManager::new(&app_handle)?));
        let window_manager = Arc::new(RwLock::new(WindowManager::new()));

        Ok(Self {
            app_handle,
            storage_manager,
            window_manager,
        })
    }
}
