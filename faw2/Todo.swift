//
//  Todo.swift
//  faw2
//
import Foundation
import FirebaseFirestore

struct Todo: Identifiable, Equatable, Codable {
    @DocumentID var id: String?
    var title: String
    var notes: String
    var isCompleted: Bool
    var createdAt: Date

    init(id: String? = nil, title: String, notes: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }

    static func == (lhs: Todo, rhs: Todo) -> Bool {
        lhs.id == rhs.id
    }
}
