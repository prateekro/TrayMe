//
//  TriggerMatcher.swift
//  TrayMe
//
//  Trie-based trigger matching for O(m) lookup where m = trigger length

import Foundation

/// Trie node for efficient trigger matching
class TrieNode {
    var children: [Character: TrieNode] = [:]
    var snippet: Snippet?
    var isEndOfWord: Bool { snippet != nil }
    
    init() {}
}

/// Trie-based trigger matcher for efficient snippet lookup
/// Time complexity: O(m) for lookup where m = length of trigger
@MainActor
class TriggerMatcher: ObservableObject {
    /// Root of the trie
    private var root = TrieNode()
    
    /// All registered snippets
    @Published private(set) var snippets: [Snippet] = []
    
    /// Whether the trie needs rebuilding
    private var isDirty = false
    
    init() {}
    
    // MARK: - Public API
    
    /// Build trie from snippets
    func build(from snippets: [Snippet]) {
        self.snippets = snippets
        rebuild()
    }
    
    /// Add a snippet to the trie
    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        insert(snippet)
    }
    
    /// Remove a snippet from the trie
    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        // Mark dirty for rebuild (faster than complex deletion)
        isDirty = true
    }
    
    /// Update a snippet
    func update(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            let oldTrigger = snippets[index].trigger
            snippets[index] = snippet
            
            // If trigger changed, rebuild
            if oldTrigger != snippet.trigger {
                isDirty = true
            }
        }
    }
    
    /// Match a trigger string
    /// - Parameter text: Text to match against triggers
    /// - Returns: Matched snippet if found
    func match(_ text: String) -> Snippet? {
        if isDirty {
            rebuild()
        }
        
        var node = root
        
        for char in text {
            guard let child = node.children[char] else {
                return nil
            }
            node = child
        }
        
        return node.snippet
    }
    
    /// Find all potential matches for a prefix
    /// - Parameter prefix: Prefix to search for
    /// - Returns: All snippets with triggers starting with prefix
    func findMatches(for prefix: String) -> [Snippet] {
        if isDirty {
            rebuild()
        }
        
        // Navigate to prefix node
        var node = root
        for char in prefix {
            guard let child = node.children[char] else {
                return []
            }
            node = child
        }
        
        // Collect all snippets under this node
        return collectSnippets(from: node)
    }
    
    /// Check if adding a trigger would conflict with existing ones
    /// - Parameter trigger: Proposed trigger
    /// - Returns: Conflicting snippet if any
    func findConflict(for trigger: String) -> Snippet? {
        // Check if trigger is prefix of existing trigger
        let prefixMatches = findMatches(for: trigger)
        if !prefixMatches.isEmpty {
            return prefixMatches.first
        }
        
        // Check if existing trigger is prefix of new trigger
        for snippet in snippets {
            if trigger.hasPrefix(snippet.trigger) {
                return snippet
            }
        }
        
        return nil
    }
    
    /// Get snippet by ID
    func snippet(withId id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }
    
    // MARK: - Private Methods
    
    /// Rebuild trie from snippets
    private func rebuild() {
        root = TrieNode()
        for snippet in snippets {
            insert(snippet)
        }
        isDirty = false
    }
    
    /// Insert a snippet into the trie
    private func insert(_ snippet: Snippet) {
        var node = root
        
        for char in snippet.trigger {
            if node.children[char] == nil {
                node.children[char] = TrieNode()
            }
            node = node.children[char]!
        }
        
        node.snippet = snippet
    }
    
    /// Collect all snippets from a node and its children
    private func collectSnippets(from node: TrieNode) -> [Snippet] {
        var results: [Snippet] = []
        
        if let snippet = node.snippet {
            results.append(snippet)
        }
        
        for (_, child) in node.children {
            results.append(contentsOf: collectSnippets(from: child))
        }
        
        return results
    }
}

// MARK: - Keyboard Buffer

/// Buffer for tracking typed characters to detect triggers
class KeyboardBuffer {
    /// Maximum buffer size (longest possible trigger)
    private let maxSize: Int
    
    /// Current buffer contents
    private var buffer: String = ""
    
    /// Debounce timer
    private var debounceTimer: Timer?
    
    /// Debounce interval in seconds
    private let debounceInterval: TimeInterval
    
    /// Callback when potential match is detected
    var onPotentialMatch: ((String) -> Void)?
    
    init(maxSize: Int = 50, debounceInterval: TimeInterval = 0.05) {
        self.maxSize = maxSize
        self.debounceInterval = debounceInterval
    }
    
    /// Add a character to the buffer
    func append(_ char: Character) {
        buffer.append(char)
        
        // Trim if too long
        if buffer.count > maxSize {
            buffer.removeFirst()
        }
        
        // Schedule debounced check
        scheduleCheck()
    }
    
    /// Add string to buffer (for pasted content)
    func append(_ string: String) {
        buffer.append(string)
        
        // Trim if too long
        if buffer.count > maxSize {
            buffer = String(buffer.suffix(maxSize))
        }
        
        scheduleCheck()
    }
    
    /// Handle backspace
    func backspace() {
        if !buffer.isEmpty {
            buffer.removeLast()
        }
    }
    
    /// Clear the buffer
    func clear() {
        buffer = ""
        debounceTimer?.invalidate()
    }
    
    /// Get current buffer contents
    var contents: String { buffer }
    
    /// Get all possible suffix matches
    var suffixes: [String] {
        var result: [String] = []
        for i in 0..<buffer.count {
            let suffix = String(buffer.suffix(buffer.count - i))
            result.append(suffix)
        }
        return result
    }
    
    // MARK: - Private Methods
    
    private func scheduleCheck() {
        debounceTimer?.invalidate()
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.onPotentialMatch?(self.buffer)
        }
    }
}

// MARK: - Character Replacement

extension TriggerMatcher {
    /// Calculate the number of characters to delete and text to insert
    /// - Parameters:
    ///   - trigger: The matched trigger
    ///   - expansion: The expanded text
    /// - Returns: Tuple of (characters to delete, text to insert)
    func calculateReplacement(trigger: String, expansion: String) -> (deleteCount: Int, insertText: String) {
        return (trigger.count, expansion)
    }
}
