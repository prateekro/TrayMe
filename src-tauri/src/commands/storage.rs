use tauri::State;
use crate::state::AppState;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkspaceInfo {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub windows: Vec<String>,
}

/// Initialize the database
#[tauri::command]
pub async fn initialize_database(
    state: State<'_, AppState>,
) -> Result<String, String> {
    tracing::info!("Initializing database");
    
    let storage_manager = state.storage_manager.read().await;
    let db_path = storage_manager.db_path().display().to_string();
    
    Ok(db_path)
}

/// Save a workspace
#[tauri::command]
pub async fn save_workspace(
    id: String,
    name: String,
    description: Option<String>,
    windows_data: String,
    state: State<'_, AppState>,
) -> Result<(), String> {
    tracing::info!("Saving workspace: {} ({})", id, name);
    
    let storage_manager = state.storage_manager.read().await;
    storage_manager
        .save_workspace(&id, &name, description.as_deref(), &windows_data)
        .await
        .map_err(|e| format!("Failed to save workspace: {}", e))?;
    
    Ok(())
}

/// Load a workspace
#[tauri::command]
pub async fn load_workspace(
    id: String,
    state: State<'_, AppState>,
) -> Result<Option<WorkspaceInfo>, String> {
    tracing::info!("Loading workspace: {}", id);
    
    let storage_manager = state.storage_manager.read().await;
    let workspace = storage_manager
        .load_workspace(&id)
        .await
        .map_err(|e| format!("Failed to load workspace: {}", e))?;
    
    Ok(workspace.map(|w| {
        let windows: Vec<String> = serde_json::from_str(&w.windows_data).unwrap_or_default();
        WorkspaceInfo {
            id: w.id,
            name: w.name,
            description: w.description,
            windows,
        }
    }))
}
