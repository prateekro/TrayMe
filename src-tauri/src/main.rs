// Prevents additional console window on Windows in release builds
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod managers;
mod models;
mod state;
mod utils;

use state::AppState;
use tauri::Manager;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn main() {
    // Initialize logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "trayme_desktop_os=debug,tauri=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Starting TrayMe Desktop OS");

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            tracing::info!("Setting up application");
            
            // Initialize app state
            let state = AppState::new(app.handle().clone())?;
            app.manage(state);

            // Set up system tray
            setup_system_tray(app)?;

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::window::minimize_to_tray,
            commands::window::restore_from_tray,
            commands::window::list_windows,
            commands::window::get_window_preview,
            commands::storage::initialize_database,
            commands::storage::save_workspace,
            commands::storage::load_workspace,
            commands::ai::query_llm,
            commands::ai::capture_screen,
            commands::ai::analyze_screenshot,
            commands::crypto::encrypt_data,
            commands::crypto::decrypt_data,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn setup_system_tray(app: &mut tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    use tauri::{
        menu::{Menu, MenuItemBuilder},
        tray::TrayIconBuilder,
    };

    let show_item = MenuItemBuilder::new("Show/Hide")
        .id("show_hide")
        .build(app)?;
    let quit_item = MenuItemBuilder::new("Quit")
        .id("quit")
        .build(app)?;

    let menu = Menu::with_items(app, &[&show_item, &quit_item])?;

    let _tray = TrayIconBuilder::new()
        .menu(&menu)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "show_hide" => {
                if let Some(window) = app.get_webview_window("main") {
                    if window.is_visible().unwrap_or(false) {
                        let _ = window.hide();
                    } else {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
            }
            "quit" => {
                app.exit(0);
            }
            _ => {}
        })
        .build(app)?;

    Ok(())
}
