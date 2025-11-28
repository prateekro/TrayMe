//
//  CacheManager.swift
//  TrayMe
//
//  High-performance LRU cache for storing temporary data with configurable TTL

import Foundation

/// Cache entry with value and metadata
struct CacheEntry<T> {
    let value: T
    let createdAt: Date
    let ttl: TimeInterval?
    var lastAccessed: Date
    
    var isExpired: Bool {
        guard let ttl = ttl else { return false }
        return Date().timeIntervalSince(createdAt) > ttl
    }
}

/// Thread-safe LRU cache using Swift actors
actor CacheManager {
    /// Shared instance for app-wide caching
    static let shared = CacheManager()
    
    /// Maximum number of items in cache
    private let maxSize: Int
    
    /// Internal cache storage with type-erased values
    private var cache: [String: Any] = [:]
    
    /// Access order for LRU eviction
    private var accessOrder: [String] = []
    
    /// Cache statistics
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    
    /// Initialize cache with configurable size
    /// - Parameter maxSize: Maximum number of items (default: 1000)
    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
    }
    
    /// Get a value from cache
    /// - Parameter key: Cache key
    /// - Returns: Cached value if found and not expired, nil otherwise
    func get<T>(_ key: String) -> T? {
        guard let entry = cache[key] as? CacheEntry<T> else {
            misses += 1
            return nil
        }
        
        // Check if expired
        if entry.isExpired {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            misses += 1
            return nil
        }
        
        // Update access order for LRU
        updateAccessOrder(key)
        
        // Update last accessed time
        var updatedEntry = entry
        updatedEntry.lastAccessed = Date()
        cache[key] = updatedEntry
        
        hits += 1
        return entry.value
    }
    
    /// Set a value in cache
    /// - Parameters:
    ///   - key: Cache key
    ///   - value: Value to cache
    ///   - ttl: Time-to-live in seconds (nil for no expiration)
    func set<T>(_ key: String, value: T, ttl: TimeInterval? = nil) {
        // Evict if at capacity
        if cache.count >= maxSize && cache[key] == nil {
            evictLRU()
        }
        
        let entry = CacheEntry(
            value: value,
            createdAt: Date(),
            ttl: ttl,
            lastAccessed: Date()
        )
        
        cache[key] = entry
        updateAccessOrder(key)
    }
    
    /// Invalidate a specific cache entry
    /// - Parameter key: Cache key to invalidate
    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    /// Clear all cache entries
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        hits = 0
        misses = 0
    }
    
    /// Get current cache size
    var size: Int {
        cache.count
    }
    
    /// Get cache hit rate (0.0 to 1.0)
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0.0 }
        return Double(hits) / Double(total)
    }
    
    /// Check if a key exists and is not expired
    func contains(_ key: String) -> Bool {
        guard let entry = cache[key] as? CacheEntry<Any> else {
            return false
        }
        return !entry.isExpired
    }
    
    /// Remove expired entries from cache
    func pruneExpired() {
        var keysToRemove: [String] = []
        
        for (key, value) in cache {
            if let entry = value as? CacheEntry<Any>, entry.isExpired {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }
    
    // MARK: - Private Methods
    
    /// Update access order for LRU tracking
    private func updateAccessOrder(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    /// Evict least recently used entry
    private func evictLRU() {
        guard !accessOrder.isEmpty else { return }
        let keyToRemove = accessOrder.removeFirst()
        cache.removeValue(forKey: keyToRemove)
    }
}

// MARK: - Convenience Extensions

extension CacheManager {
    /// Get or set a value using a factory function
    /// - Parameters:
    ///   - key: Cache key
    ///   - ttl: Time-to-live for new entries
    ///   - factory: Factory function to create value if not cached
    /// - Returns: Cached or newly created value
    func getOrSet<T>(_ key: String, ttl: TimeInterval? = nil, factory: () async -> T) async -> T {
        if let cached: T = await get(key) {
            return cached
        }
        
        let value = await factory()
        await set(key, value: value, ttl: ttl)
        return value
    }
}
