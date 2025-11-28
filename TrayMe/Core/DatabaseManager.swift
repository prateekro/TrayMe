//
//  DatabaseManager.swift
//  TrayMe
//
//  SQLite database manager for analytics and persistent storage

import Foundation
import SQLite3

/// SQLite database manager with high-performance configuration
actor DatabaseManager {
    /// Shared instance for app-wide database access
    static let shared = DatabaseManager()
    
    /// SQLite database handle
    private var db: OpaquePointer?
    
    /// Database file URL
    private let databaseURL: URL
    
    /// Whether database is initialized
    private var isInitialized = false
    
    init() {
        // Get Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        databaseURL = appFolder.appendingPathComponent("trayme.db")
    }
    
    /// Open database connection
    func open() throws {
        guard db == nil else { return }
        
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        
        if sqlite3_open_v2(databaseURL.path, &db, flags, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.openFailed(errorMessage)
        }
        
        // Enable WAL mode for better concurrency
        try execute("PRAGMA journal_mode = WAL")
        
        // Enable foreign keys
        try execute("PRAGMA foreign_keys = ON")
        
        // Optimize for performance
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA cache_size = -64000") // 64MB cache
        try execute("PRAGMA temp_store = MEMORY")
        
        isInitialized = true
    }
    
    /// Close database connection
    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
            isInitialized = false
        }
    }
    
    /// Execute a SQL statement without results
    func execute(_ sql: String) throws {
        guard let db = db else {
            throw DatabaseError.notOpen
        }
        
        var errorMessage: UnsafeMutablePointer<CChar>?
        
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.executionFailed(message)
        }
    }
    
    /// Execute a SQL statement with parameters
    func execute(_ sql: String, parameters: [Any?]) throws {
        guard let db = db else {
            throw DatabaseError.notOpen
        }
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)
            
            switch param {
            case nil:
                sqlite3_bind_null(statement, idx)
            case let value as Int:
                sqlite3_bind_int64(statement, idx, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, idx, value)
            case let value as Double:
                sqlite3_bind_double(statement, idx, value)
            case let value as String:
                sqlite3_bind_text(statement, idx, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let value as Data:
                value.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, idx, bytes.baseAddress, Int32(value.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case let value as Date:
                let iso8601 = ISO8601DateFormatter().string(from: value)
                sqlite3_bind_text(statement, idx, iso8601, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            default:
                throw DatabaseError.unsupportedType("\(type(of: param))")
            }
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executionFailed(errorMessage)
        }
    }
    
    /// Query with results
    func query(_ sql: String, parameters: [Any?] = []) throws -> [[String: Any?]] {
        guard let db = db else {
            throw DatabaseError.notOpen
        }
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)
            
            switch param {
            case nil:
                sqlite3_bind_null(statement, idx)
            case let value as Int:
                sqlite3_bind_int64(statement, idx, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, idx, value)
            case let value as Double:
                sqlite3_bind_double(statement, idx, value)
            case let value as String:
                sqlite3_bind_text(statement, idx, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let value as Data:
                value.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, idx, bytes.baseAddress, Int32(value.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case let value as Date:
                let iso8601 = ISO8601DateFormatter().string(from: value)
                sqlite3_bind_text(statement, idx, iso8601, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            default:
                throw DatabaseError.unsupportedType("\(type(of: param))")
            }
        }
        
        var results: [[String: Any?]] = []
        let columnCount = sqlite3_column_count(statement)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any?] = [:]
            
            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                let columnType = sqlite3_column_type(statement, i)
                
                switch columnType {
                case SQLITE_NULL:
                    row[columnName] = nil
                case SQLITE_INTEGER:
                    row[columnName] = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT:
                    row[columnName] = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, i) {
                        row[columnName] = String(cString: text)
                    }
                case SQLITE_BLOB:
                    if let blob = sqlite3_column_blob(statement, i) {
                        let size = sqlite3_column_bytes(statement, i)
                        row[columnName] = Data(bytes: blob, count: Int(size))
                    }
                default:
                    row[columnName] = nil
                }
            }
            
            results.append(row)
        }
        
        return results
    }
    
    /// Get last inserted row ID
    func lastInsertRowId() -> Int64 {
        guard let db = db else { return 0 }
        return sqlite3_last_insert_rowid(db)
    }
    
    /// Get number of rows affected by last operation
    func changes() -> Int {
        guard let db = db else { return 0 }
        return Int(sqlite3_changes(db))
    }
    
    /// Begin a transaction
    func beginTransaction() throws {
        try execute("BEGIN TRANSACTION")
    }
    
    /// Commit a transaction
    func commit() throws {
        try execute("COMMIT")
    }
    
    /// Rollback a transaction
    func rollback() throws {
        try execute("ROLLBACK")
    }
    
    /// Execute multiple operations in a transaction
    func transaction(_ operations: () async throws -> Void) async throws {
        try beginTransaction()
        do {
            try await operations()
            try commit()
        } catch {
            try? rollback()
            throw error
        }
    }
    
    /// Create an index if it doesn't exist
    func createIndex(name: String, table: String, columns: [String], unique: Bool = false) throws {
        let uniqueStr = unique ? "UNIQUE" : ""
        let columnsStr = columns.joined(separator: ", ")
        try execute("CREATE \(uniqueStr) INDEX IF NOT EXISTS \(name) ON \(table) (\(columnsStr))")
    }
    
    /// Check if database is open and initialized
    var isOpen: Bool {
        db != nil && isInitialized
    }
    
    deinit {
        close()
    }
}

// MARK: - Database Errors

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case notOpen
    case prepareFailed(String)
    case executionFailed(String)
    case unsupportedType(String)
    
    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Failed to open database: \(message)"
        case .notOpen:
            return "Database is not open"
        case .prepareFailed(let message):
            return "Failed to prepare statement: \(message)"
        case .executionFailed(let message):
            return "Failed to execute statement: \(message)"
        case .unsupportedType(let type):
            return "Unsupported parameter type: \(type)"
        }
    }
}

// MARK: - Table Creation Helpers

extension DatabaseManager {
    /// Create analytics tables
    func createAnalyticsTables() async throws {
        // Analytics events table
        try execute("""
            CREATE TABLE IF NOT EXISTS analytics_events (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                metadata TEXT
            )
        """)
        
        // Create index on timestamp for time-based queries
        try createIndex(name: "idx_events_timestamp", table: "analytics_events", columns: ["timestamp"])
        try createIndex(name: "idx_events_type", table: "analytics_events", columns: ["type"])
        
        // Daily aggregates table for faster queries
        try execute("""
            CREATE TABLE IF NOT EXISTS analytics_daily (
                date TEXT PRIMARY KEY,
                clipboard_copies INTEGER DEFAULT 0,
                clipboard_pastes INTEGER DEFAULT 0,
                snippets_used INTEGER DEFAULT 0,
                files_added INTEGER DEFAULT 0,
                files_opened INTEGER DEFAULT 0,
                notes_created INTEGER DEFAULT 0
            )
        """)
        
        // Category distribution table
        try execute("""
            CREATE TABLE IF NOT EXISTS category_stats (
                category TEXT PRIMARY KEY,
                count INTEGER DEFAULT 0,
                last_updated TEXT
            )
        """)
    }
    
    /// Create snippets tables
    func createSnippetsTables() async throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS snippets (
                id TEXT PRIMARY KEY,
                trigger TEXT NOT NULL UNIQUE,
                expansion TEXT NOT NULL,
                category TEXT,
                usage_count INTEGER DEFAULT 0,
                last_used TEXT,
                created_at TEXT NOT NULL,
                variables TEXT
            )
        """)
        
        try createIndex(name: "idx_snippets_trigger", table: "snippets", columns: ["trigger"], unique: true)
        try createIndex(name: "idx_snippets_category", table: "snippets", columns: ["category"])
    }
    
    /// Create security tables
    func createSecurityTables() async throws {
        // Sensitive items table (encrypted)
        try execute("""
            CREATE TABLE IF NOT EXISTS sensitive_items (
                id TEXT PRIMARY KEY,
                encrypted_data BLOB NOT NULL,
                type TEXT NOT NULL,
                created_at TEXT NOT NULL,
                auto_delete_at TEXT
            )
        """)
        
        // Access log for security auditing
        try execute("""
            CREATE TABLE IF NOT EXISTS access_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                success INTEGER NOT NULL
            )
        """)
        
        try createIndex(name: "idx_access_log_timestamp", table: "access_log", columns: ["timestamp"])
    }
}
