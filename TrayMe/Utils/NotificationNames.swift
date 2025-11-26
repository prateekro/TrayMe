//
//  NotificationNames.swift
//  TrayMe
//

import Foundation

// Centralized notification names to prevent typos and inconsistencies
extension Notification.Name {
    static let mainPanelWillHide = Notification.Name("MainPanelWillHide")
    static let focusNotes = Notification.Name("FocusNotes")
}
