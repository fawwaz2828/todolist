//
//  ContentView.swift
//  faw2
//
import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - TodoStore

final class TodoStore: ObservableObject {
    @Published var todos: [Todo] = []

    private var db: Firestore? { isPreview ? nil : Firestore.firestore() }
    private var listener: ListenerRegistration?
    private let isPreview: Bool

    init(preview: Bool = false) {
        self.isPreview = preview

        if preview {
            self.todos = [
                Todo(id: "1", title: "Belajar SwiftUI", notes: "State vs ObservableObject"),
                Todo(id: "2", title: "Integrasi Firestore", notes: "Sudah selesai", isCompleted: true),
                Todo(id: "3", title: "Submit ke App Store", notes: ""),
            ]
            return
        }

        listener = Firestore.firestore()
            .collection("todos")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Firestore error: \(error)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    self?.todos = docs.compactMap { try? $0.data(as: Todo.self) }
                }
            }
    }

    deinit {
        listener?.remove()
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isPreview {
            todos.insert(Todo(id: UUID().uuidString, title: trimmed), at: 0)
            return
        }
        let todo = Todo(title: trimmed)
        do {
            try db?.collection("todos").addDocument(from: todo)
        } catch {
            print("Gagal tambah todo: \(error)")
        }
    }

    func removeTodos(at offsets: IndexSet) {
        if isPreview {
            todos.remove(atOffsets: offsets)
            return
        }
        offsets.forEach { index in
            let todo = todos[index]
            guard let id = todo.id else { return }
            db?.collection("todos").document(id).delete()
        }
    }

    func removeTodo(id: String) {
        if isPreview {
            todos.removeAll { $0.id == id }
            return
        }
        db?.collection("todos").document(id).delete()
    }

    func update(_ todo: Todo) {
        if isPreview {
            guard let i = todos.firstIndex(where: { $0.id == todo.id }) else { return }
            todos[i] = todo
            return
        }
        guard let id = todo.id else { return }
        do {
            try db?.collection("todos").document(id).setData(from: todo)
        } catch {
            print("Gagal update todo: \(error)")
        }
    }

    func binding(for id: String) -> Binding<Todo> {
        Binding(
            get: {
                self.todos.first { $0.id == id }
                    ?? Todo(id: id, title: "", notes: "")
            },
            set: { updated in
                self.update(updated)
            }
        )
    }

    func flushToDisk() {
        // Tidak diperlukan — Firestore menyimpan otomatis
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var newTodoTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AddTodoRow(title: $newTodoTitle) {
                        store.add(title: newTodoTitle)
                        newTodoTitle = ""
                    }
                }

                Section("Tasks") {
                    ForEach(store.todos) { todo in
                        NavigationLink(value: todo.id) {
                            TodoRowLabel(todo: todo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                guard let id = todo.id else { return }
                                store.removeTodo(id: id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.removeTodos(at: offsets)
                    }
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .navigationDestination(for: String.self) { id in
                TodoDetailView(todo: store.binding(for: id))
            }
        }
    }
}

// MARK: - Subviews

private struct TodoRowLabel: View {
    let todo: Todo

    var body: some View {
        HStack {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .strikethrough(todo.isCompleted)
                if !todo.notes.isEmpty {
                    Text(todo.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct AddTodoRow: View {
    @Binding var title: String
    var onCommit: () -> Void

    var body: some View {
        HStack {
            TextField("New task", text: $title)
                .textInputAutocapitalization(.sentences)
                .onSubmit(onCommit)
            Button("Add", action: onCommit)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

// MARK: - Detail View

struct TodoDetailView: View {
    @Binding var todo: Todo
    @EnvironmentObject private var store: TodoStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $todo.title)
            }
            Section("Notes") {
                TextField("Notes", text: $todo.notes, axis: .vertical)
                    .lineLimit(3 ... 8)
            }
            Section {
                Toggle("Completed", isOn: $todo.isCompleted)
            }
            Section {
                Button(role: .destructive) {
                    guard let id = todo.id else { return }
                    store.removeTodo(id: id)
                    dismiss()
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(TodoStore(preview: true))
    }
}
