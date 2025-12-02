//
//  ClipboardRulesEngine.swift
//  TrayMe
//
//  Rules engine for automatic clipboard processing

import Foundation
import SwiftUI
import UserNotifications

/// Condition types for clipboard rules
enum RuleCondition: Codable, Equatable {
    case sourceApp(bundleId: String)
    case contentType(ClipboardCategory)
    case regexMatch(pattern: String)
    case containsText(text: String)
    case contentLength(comparison: ComparisonType, value: Int)
    case timeOfDay(start: Int, end: Int)  // Hours 0-23
    
    enum ComparisonType: String, Codable {
        case lessThan = "<"
        case greaterThan = ">"
        case equals = "="
    }
    
    var displayName: String {
        switch self {
        case .sourceApp(let bundleId):
            return "From app: \(bundleId.components(separatedBy: ".").last ?? bundleId)"
        case .contentType(let type):
            return "Content type: \(type.rawValue)"
        case .regexMatch(let pattern):
            return "Matches: \(pattern)"
        case .containsText(let text):
            return "Contains: \(text)"
        case .contentLength(let comparison, let value):
            return "Length \(comparison.rawValue) \(value)"
        case .timeOfDay(let start, let end):
            return "Time: \(start):00 - \(end):00"
        }
    }
    
    func evaluate(item: ClipboardItem) -> Bool {
        switch self {
        case .sourceApp(let bundleId):
            return item.sourceApp?.lowercased().contains(bundleId.lowercased()) ?? false
            
        case .contentType(let type):
            return item.category == type
            
        case .regexMatch(let pattern):
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return false
            }
            return regex.firstMatch(in: item.content, options: [], range: NSRange(item.content.startIndex..., in: item.content)) != nil
            
        case .containsText(let text):
            return item.content.localizedCaseInsensitiveContains(text)
            
        case .contentLength(let comparison, let value):
            switch comparison {
            case .lessThan: return item.content.count < value
            case .greaterThan: return item.content.count > value
            case .equals: return item.content.count == value
            }
            
        case .timeOfDay(let start, let end):
            let hour = Calendar.current.component(.hour, from: Date())
            if start <= end {
                return hour >= start && hour < end
            } else {
                // Wraps around midnight
                return hour >= start || hour < end
            }
        }
    }
}

/// Actions that can be performed on clipboard items
enum RuleAction: Codable, Equatable {
    case autoFavorite
    case autoDelete(afterSeconds: Int)
    case addToCategory(name: String)
    case transform(type: TransformType)
    case notify(title: String, message: String)
    case copyToFile(folder: String)
    
    enum TransformType: String, Codable {
        case uppercase
        case lowercase
        case trimWhitespace
        case removeNewlines
        case urlEncode
        case urlDecode
        case base64Encode
        case base64Decode
    }
    
    var displayName: String {
        switch self {
        case .autoFavorite:
            return "Auto-favorite"
        case .autoDelete(let seconds):
            return "Auto-delete after \(seconds)s"
        case .addToCategory(let name):
            return "Add to category: \(name)"
        case .transform(let type):
            return "Transform: \(type.rawValue)"
        case .notify(let title, _):
            return "Notify: \(title)"
        case .copyToFile(let folder):
            return "Save to: \(folder)"
        }
    }
    
    func execute(on item: inout ClipboardItem, manager: ClipboardManager?) {
        switch self {
        case .autoFavorite:
            item.isFavorite = true
            
        case .autoDelete(let seconds):
            // Schedule deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) { [weak manager] in
                manager?.deleteItem(item)
            }
            
        case .addToCategory:
            // Categories are auto-detected, but this could add a custom tag
            break
            
        case .transform(let type):
            // Transform content
            let transformed = applyTransform(type, to: item.content)
            // Create new item with transformed content
            // Note: This would need manager access to update
            break
            
        case .notify(let title, let message):
            // Show notification
            sendNotification(title: title, body: message.replacingOccurrences(of: "${content}", with: String(item.content.prefix(50))))
            
        case .copyToFile(let folder):
            // Save content to file
            saveToFile(content: item.content, folder: folder, timestamp: item.timestamp)
        }
    }
    
    private func applyTransform(_ type: TransformType, to content: String) -> String {
        switch type {
        case .uppercase: return content.uppercased()
        case .lowercase: return content.lowercased()
        case .trimWhitespace: return content.trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeNewlines: return content.replacingOccurrences(of: "\n", with: " ")
        case .urlEncode: return content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? content
        case .urlDecode: return content.removingPercentEncoding ?? content
        case .base64Encode: return Data(content.utf8).base64EncodedString()
        case .base64Decode:
            if let data = Data(base64Encoded: content), let decoded = String(data: data, encoding: .utf8) {
                return decoded
            }
            return content
        }
    }
    
    private func sendNotification(title: String, body: String) {
        // Use UserNotifications framework for modern macOS
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveToFile(content: String, folder: String, timestamp: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "clip_\(formatter.string(from: timestamp)).txt"
        
        let folderURL = URL(fileURLWithPath: folder).expandingTildeInPath()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let fileURL = folderURL.appendingPathComponent(filename)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

/// A clipboard rule with conditions and actions
struct ClipboardRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var conditions: [RuleCondition]
    var conditionLogic: ConditionLogic
    var actions: [RuleAction]
    var priority: Int
    
    enum ConditionLogic: String, Codable {
        case all  // AND
        case any  // OR
    }
    
    init(name: String, conditions: [RuleCondition] = [], conditionLogic: ConditionLogic = .all, actions: [RuleAction] = [], priority: Int = 0) {
        self.id = UUID()
        self.name = name
        self.isEnabled = true
        self.conditions = conditions
        self.conditionLogic = conditionLogic
        self.actions = actions
        self.priority = priority
    }
    
    func matches(_ item: ClipboardItem) -> Bool {
        guard isEnabled else { return false }
        
        if conditions.isEmpty { return false }
        
        switch conditionLogic {
        case .all:
            return conditions.allSatisfy { $0.evaluate(item: item) }
        case .any:
            return conditions.contains { $0.evaluate(item: item) }
        }
    }
    
    func execute(on item: inout ClipboardItem, manager: ClipboardManager?) {
        for action in actions {
            action.execute(on: &item, manager: manager)
        }
    }
}

/// Rules engine manager
class ClipboardRulesEngine: ObservableObject {
    @Published var rules: [ClipboardRule] = []
    
    private let saveKey = "TrayMe.ClipboardRules"
    
    init() {
        loadRules()
        if rules.isEmpty {
            addDefaultRules()
        }
    }
    
    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ClipboardRule].self, from: data) {
            rules = decoded.sorted { $0.priority > $1.priority }
        }
    }
    
    func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func addRule(_ rule: ClipboardRule) {
        rules.append(rule)
        rules.sort { $0.priority > $1.priority }
        saveRules()
    }
    
    func updateRule(_ rule: ClipboardRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }
    
    func deleteRule(_ rule: ClipboardRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }
    
    func processItem(_ item: inout ClipboardItem, manager: ClipboardManager?) {
        for rule in rules where rule.isEnabled && rule.matches(item) {
            rule.execute(on: &item, manager: manager)
        }
    }
    
    private func addDefaultRules() {
        let defaultRules = [
            ClipboardRule(
                name: "Auto-favorite GitHub URLs",
                conditions: [
                    .contentType(.url),
                    .containsText("github.com")
                ],
                actions: [.autoFavorite]
            ),
            ClipboardRule(
                name: "Notify on email copy",
                conditions: [.contentType(.email)],
                actions: [.notify(title: "Email Copied", message: "${content}")]
            ),
        ]
        
        rules = defaultRules
        saveRules()
    }
}

// MARK: - URL Extension

extension URL {
    func expandingTildeInPath() -> URL {
        if path.hasPrefix("~") {
            let expandedPath = NSString(string: path).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }
        return self
    }
}
