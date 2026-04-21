//
//  Task.swift
//  faw2
//
import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Priority

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var color: Color {
        switch self {
        case .low:    return .blue
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var icon: String {
        switch self {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        }
    }

    var sortOrder: Int {
        switch self {
        case .high:   return 0
        case .medium: return 1
        case .low:    return 2
        }
    }
}

// MARK: - TaskStatus

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo, inProgress, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo:       return "To Do"
        case .inProgress: return "In Progress"
        case .done:       return "Done"
        }
    }

    var icon: String {
        switch self {
        case .todo:       return "circle"
        case .inProgress: return "clock.fill"
        case .done:       return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .todo:       return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }
}

// MARK: - TodoItem
// Named TodoItem (not Task) to avoid conflict with Swift's concurrency Task type.

struct TodoItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var note: String?
    var dueDate: Date?
    var priority: Priority
    var status: TaskStatus
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String? = nil,
        title: String,
        note: String? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium,
        status: TaskStatus = .todo,
        category: String? = nil
    ) {
        self.id       = id
        self.title    = title
        self.note     = note
        self.dueDate  = dueDate
        self.priority = priority
        self.status   = status
        self.category = category
        let now       = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    var isOverdue: Bool {
        guard let due = dueDate, status != .done else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let due = dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    var formattedDueDate: String? {
        guard let due = dueDate else { return nil }
        if Calendar.current.isDateInToday(due)     { return "Today" }
        if Calendar.current.isDateInTomorrow(due)  { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(due) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: due)
    }
}
