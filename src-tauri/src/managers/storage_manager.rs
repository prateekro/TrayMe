use anyhow::{Context, Result};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::path::PathBuf;
use std::str::FromStr;
use tauri::{AppHandle, Manager};

/// Manages local SQLite database for persistent storage
pub struct StorageManager {
    pool: SqlitePool,
    db_path: PathBuf,
}

impl StorageManager {
    /// Initialize the storage manager with SQLite database
    pub fn new(app_handle: &AppHandle) -> Result<Self> {
        let app_dir = app_handle
            .path()
            .app_data_dir()
            .context("Failed to get app data directory")?;
        
        std::fs::create_dir_all(&app_dir)
            .context("Failed to create app data directory")?;

        let db_path = app_dir.join("trayme.db");
        
        tracing::info!("Database path: {:?}", db_path);

        // Create a runtime for async operations
        let rt = tokio::runtime::Runtime::new()?;
        
        let pool = rt.block_on(async {
            let options = SqliteConnectOptions::from_str(&format!("sqlite:{}", db_path.display()))?
                .create_if_missing(true);

            SqlitePoolOptions::new()
                .max_connections(5)
                .connect_with(options)
                .await
                .context("Failed to connect to database")
        })?;

        // Initialize database schema
        rt.block_on(async {
            Self::initialize_schema(&pool).await
        })?;

        Ok(Self { pool, db_path })
    }

    /// Initialize database schema with all required tables
    async fn initialize_schema(pool: &SqlitePool) -> Result<()> {
        tracing::info!("Initializing database schema");

        // Workspaces table
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS workspaces (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                windows_data TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            "#,
        )
        .execute(pool)
        .await?;

        // Settings table
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            )
            "#,
        )
        .execute(pool)
        .await?;

        // RAG documents table (for future AI integration)
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                embedding BLOB,
                metadata TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            "#,
        )
        .execute(pool)
        .await?;

        tracing::info!("Database schema initialized successfully");
        Ok(())
    }

    /// Get the database connection pool
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }

    /// Get the database file path
    pub fn db_path(&self) -> &PathBuf {
        &self.db_path
    }

    /// Save workspace data to database
    pub async fn save_workspace(&self, id: &str, name: &str, description: Option<&str>, windows_data: &str) -> Result<()> {
        let now = chrono::Utc::now().timestamp();
        
        sqlx::query(
            r#"
            INSERT INTO workspaces (id, name, description, windows_data, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                windows_data = excluded.windows_data,
                updated_at = excluded.updated_at
            "#,
        )
        .bind(id)
        .bind(name)
        .bind(description)
        .bind(windows_data)
        .bind(now)
        .bind(now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// Load workspace data from database
    pub async fn load_workspace(&self, id: &str) -> Result<Option<WorkspaceData>> {
        let row = sqlx::query_as::<_, WorkspaceRow>(
            "SELECT id, name, description, windows_data, created_at, updated_at FROM workspaces WHERE id = ?"
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(|r| WorkspaceData {
            id: r.id,
            name: r.name,
            description: r.description,
            windows_data: r.windows_data,
            created_at: r.created_at,
            updated_at: r.updated_at,
        }))
    }

    /// List all workspaces
    pub async fn list_workspaces(&self) -> Result<Vec<WorkspaceData>> {
        let rows = sqlx::query_as::<_, WorkspaceRow>(
            "SELECT id, name, description, windows_data, created_at, updated_at FROM workspaces ORDER BY updated_at DESC"
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(|r| WorkspaceData {
            id: r.id,
            name: r.name,
            description: r.description,
            windows_data: r.windows_data,
            created_at: r.created_at,
            updated_at: r.updated_at,
        }).collect())
    }
}

#[derive(sqlx::FromRow)]
struct WorkspaceRow {
    id: String,
    name: String,
    description: Option<String>,
    windows_data: String,
    created_at: i64,
    updated_at: i64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct WorkspaceData {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub windows_data: String,
    pub created_at: i64,
    pub updated_at: i64,
}
