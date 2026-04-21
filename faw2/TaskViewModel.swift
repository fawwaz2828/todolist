//
//  TaskViewModel.swift
//  faw2
//
import Foundation
import FirebaseFirestore

// MARK: - Task Filter

enum TaskFilter: String, CaseIterable, Identifiable {
    case all   = "All"
    case today = "Today"
    case done  = "Done"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:   return "tray.full"
        case .today: return "calendar"
        case .done:  return "checkmark.circle"
        }
    }
}

// MARK: - TaskViewModel

@MainActor
final class TaskViewModel: ObservableObject {

    @Published var items: [TodoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: TaskFilter = .all
    @Published var searchText = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let userId: String

    private var collection: CollectionReference {
        db.collection("users").document(userId).collection("tasks")
    }

    init(userId: String) {
        self.userId = userId
        fetchItems()
    }

    deinit { listener?.remove() }

    // MARK: - Derived counts

    var activeCount: Int { items.filter { $0.status != .done }.count }
    var todayCount:  Int { items.filter { $0.isDueToday && $0.status != .done }.count }
    var doneCount:   Int { items.filter { $0.status == .done }.count }

    // MARK: - Filtered + sorted

    var filteredItems: [TodoItem] {
        var result: [TodoItem]

        switch selectedFilter {
        case .all:
            result = items.filter { $0.status != .done }
        case .today:
            result = items.filter { $0.isDueToday && $0.status != .done }
        case .done:
            result = items.filter { $0.status == .done }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
                || ($0.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result.sorted {
            if $0.isOverdue != $1.isOverdue { return $0.isOverdue }
            if $0.priority.sortOrder != $1.priority.sortOrder {
                return $0.priority.sortOrder < $1.priority.sortOrder
            }
            return $0.createdAt > $1.createdAt
        }
    }

    // MARK: - Firestore CRUD

    func fetchItems() {
        isLoading = true
        listener = collection
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                isLoading = false
                if let error {
                    errorMessage = error.localizedDescription
                    return
                }
                items = (snapshot?.documents ?? []).compactMap {
                    try? $0.data(as: TodoItem.self)
                }
            }
    }

    func addItem(_ item: TodoItem) {
        do {
            _ = try collection.addDocument(from: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateItem(_ item: TodoItem) {
        guard let id = item.id else { return }
        var updated = item
        updated.updatedAt = Date()
        do {
            try collection.document(id).setData(from: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(id: String) {
        collection.document(id).delete { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cycleStatus(for item: TodoItem) {
        var updated = item
        switch item.status {
        case .todo:       updated.status = .inProgress
        case .inProgress: updated.status = .done
        case .done:       updated.status = .todo
        }
        updateItem(updated)
    }

    func toggleDone(_ item: TodoItem) {
        var updated = item
        updated.status = item.status == .done ? .todo : .done
        updateItem(updated)
    }
}
