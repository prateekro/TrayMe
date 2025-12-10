use tauri::State;
use crate::state::AppState;
use crate::managers::window_manager::TrayedWindow;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct WindowInfo {
    pub id: String,
    pub title: String,
    pub app_name: String,
    pub workspace: Option<String>,
}

/// Minimize a window to the tray
#[tauri::command]
pub async fn minimize_to_tray(
    title: String,
    app_name: String,
    state: State<'_, AppState>,
) -> Result<String, String> {
    tracing::info!("Minimizing window to tray: {} ({})", title, app_name);
    
    let window = TrayedWindow::new(title, app_name);
    let id = window.id.clone();
    
    let mut window_manager = state.window_manager.write().await;
    window_manager.add_to_tray(window);
    
    Ok(id)
}

/// Restore a window from the tray
#[tauri::command]
pub async fn restore_from_tray(
    id: String,
    state: State<'_, AppState>,
) -> Result<WindowInfo, String> {
    tracing::info!("Restoring window from tray: {}", id);
    
    let mut window_manager = state.window_manager.write().await;
    let window = window_manager
        .remove_from_tray(&id)
        .ok_or_else(|| format!("Window not found: {}", id))?;
    
    Ok(WindowInfo {
        id: window.id,
        title: window.title,
        app_name: window.app_name,
        workspace: window.workspace,
    })
}

/// List all windows in the tray
#[tauri::command]
pub async fn list_windows(
    state: State<'_, AppState>,
) -> Result<Vec<WindowInfo>, String> {
    tracing::info!("Listing all trayed windows");
    
    let window_manager = state.window_manager.read().await;
    let windows = window_manager
        .list_trayed_windows()
        .iter()
        .map(|w| WindowInfo {
            id: w.id.clone(),
            title: w.title.clone(),
            app_name: w.app_name.clone(),
            workspace: w.workspace.clone(),
        })
        .collect();
    
    Ok(windows)
}

/// Get window preview (placeholder for future screenshot functionality)
#[tauri::command]
pub async fn get_window_preview(
    id: String,
    state: State<'_, AppState>,
) -> Result<Option<Vec<u8>>, String> {
    tracing::info!("Getting window preview: {}", id);
    
    let window_manager = state.window_manager.read().await;
    let window = window_manager
        .get_trayed_window(&id)
        .ok_or_else(|| format!("Window not found: {}", id))?;
    
    Ok(window.preview_data.clone())
}
