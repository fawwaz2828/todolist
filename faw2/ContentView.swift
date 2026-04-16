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

    private var activeTodos: [Todo] { store.todos.filter { !$0.isCompleted } }
    private var completedTodos: [Todo] { store.todos.filter { $0.isCompleted } }
    private var progress: Double {
        guard !store.todos.isEmpty else { return 0 }
        return Double(completedTodos.count) / Double(store.todos.count)
    }

    var body: some View {
        NavigationStack {
            List {
                // Progress card
                if !store.todos.isEmpty {
                    Section {
                        ProgressCard(
                            total: store.todos.count,
                            completed: completedTodos.count,
                            progress: progress
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                // Input tambah task
                Section {
                    AddTodoRow(title: $newTodoTitle) {
                        store.add(title: newTodoTitle)
                        newTodoTitle = ""
                    }
                }

                // Task aktif
                if !activeTodos.isEmpty {
                    Section {
                        ForEach(activeTodos) { todo in
                            NavigationLink(value: todo.id) {
                                TodoRowLabel(todo: todo)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    guard let id = todo.id else { return }
                                    store.removeTodo(id: id)
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    var updated = todo
                                    updated.isCompleted = true
                                    store.update(updated)
                                } label: {
                                    Label("Selesai", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    } header: {
                        SectionHeader(
                            icon: "circle.dotted",
                            title: "Aktif",
                            count: activeTodos.count
                        )
                    }
                }

                // Empty state
                if store.todos.isEmpty {
                    Section {
                        EmptyStateView()
                    }
                    .listRowBackground(Color.clear)
                }

                // Task selesai
                if !completedTodos.isEmpty {
                    Section {
                        ForEach(completedTodos) { todo in
                            NavigationLink(value: todo.id) {
                                TodoRowLabel(todo: todo)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    guard let id = todo.id else { return }
                                    store.removeTodo(id: id)
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    var updated = todo
                                    updated.isCompleted = false
                                    store.update(updated)
                                } label: {
                                    Label("Aktifkan", systemImage: "arrow.uturn.left")
                                }
                                .tint(.orange)
                            }
                        }
                    } header: {
                        SectionHeader(
                            icon: "checkmark.circle",
                            title: "Selesai",
                            count: completedTodos.count
                        )
                    }
                }
            }
            .navigationTitle("My Tasks")
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

// MARK: - Progress Card

private struct ProgressCard: View {
    let total: Int
    let completed: Int
    let progress: Double

    private var tint: Color { progress >= 1.0 ? .green : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completed) dari \(total) task selesai")
                        .font(.subheadline.weight(.medium))
                    if progress >= 1.0 {
                        Text("Semua task sudah selesai!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            ProgressView(value: progress)
                .tint(tint)
                .animation(.spring(response: 0.4), value: progress)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let icon: String
    let title: String
    let count: Int

    var body: some View {
        Label {
            Text("\(title) (\(count))")
        } icon: {
            Image(systemName: icon)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.primary)
        .textCase(nil)
    }
}

// MARK: - Todo Row Label

private struct TodoRowLabel: View {
    let todo: Todo

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(
                        todo.isCompleted ? Color.green : Color.secondary.opacity(0.4),
                        lineWidth: 1.5
                    )
                    .frame(width: 26, height: 26)
                if todo.isCompleted {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                if !todo.notes.isEmpty {
                    Text(todo.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Add Todo Row

private struct AddTodoRow: View {
    @Binding var title: String
    var onCommit: () -> Void
    @FocusState private var isFocused: Bool

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(isFocused ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isFocused)

            TextField("Tambah task baru…", text: $title)
                .textInputAutocapitalization(.sentences)
                .focused($isFocused)
                .onSubmit(onCommit)

            if canAdd {
                Button(action: onCommit) {
                    Text("Tambah")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.accentColor, in: Capsule())
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canAdd)
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 52))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Belum ada task")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tambahkan task pertama kamu di atas")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Detail View

struct TodoDetailView: View {
    @Binding var todo: Todo
    @EnvironmentObject private var store: TodoStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                todo.isCompleted ? Color.green : Color.secondary.opacity(0.4),
                                lineWidth: 2
                            )
                            .frame(width: 28, height: 28)
                        if todo.isCompleted {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            todo.isCompleted.toggle()
                        }
                    }
                    TextField("Judul task", text: $todo.title)
                        .font(.body.weight(.medium))
                }
            } header: {
                Text("Task")
            }

            Section {
                TextField("Tambah catatan…", text: $todo.notes, axis: .vertical)
                    .lineLimit(3 ... 8)
            } header: {
                Text("Catatan")
            }

            Section {
                Toggle(isOn: $todo.isCompleted.animation()) {
                    Label {
                        Text("Tandai Selesai")
                    } icon: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    }
                }
                .tint(.green)
            }

            Section {
                Button(role: .destructive) {
                    guard let id = todo.id else { return }
                    store.removeTodo(id: id)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Label("Hapus Task", systemImage: "trash")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(todo.isCompleted ? "Task Selesai" : "Edit Task")
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
