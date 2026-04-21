//
//  AddEditTaskView.swift
//  faw2
//
import SwiftUI

// MARK: - AddEditTaskView

struct AddEditTaskView: View {

    @EnvironmentObject private var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    var existingItem: TodoItem?

    @State private var title           = ""
    @State private var note            = ""
    @State private var hasDueDate      = false
    @State private var dueDate         = Date()
    @State private var priority        = Priority.medium
    @State private var status          = TaskStatus.todo
    @State private var category        = ""
    @State private var showDeleteAlert = false

    private var isEditing: Bool { existingItem != nil }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.14),
                        Color(red: 0.08, green: 0.04, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {

                        // ── Task Details ──────────────────────────────────
                        GlassSection(title: "Task Details") {
                            GlassField {
                                TextField("Title", text: $title)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.white)
                            }
                            GlassDivider()
                            GlassField {
                                ZStack(alignment: .topLeading) {
                                    if note.isEmpty {
                                        Text("Notes (optional)")
                                            .foregroundColor(.white.opacity(0.3))
                                            .font(.body)
                                            .padding(.top, 0)
                                    }
                                    TextEditor(text: $note)
                                        .foregroundColor(.white)
                                        .frame(minHeight: 72)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                            }
                        }

                        // ── Schedule ──────────────────────────────────────
                        GlassSection(title: "Schedule") {
                            GlassField {
                                Toggle(isOn: $hasDueDate.animation()) {
                                    Label("Due Date", systemImage: "calendar")
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .tint(.accentColor)
                            }
                            if hasDueDate {
                                GlassDivider()
                                GlassField {
                                    DatePicker(
                                        "Date",
                                        selection: $dueDate,
                                        displayedComponents: .date
                                    )
                                    .foregroundColor(.white)
                                    .colorScheme(.dark)
                                }
                            }
                        }

                        // ── Priority ──────────────────────────────────────
                        GlassSection(title: "Priority") {
                            HStack(spacing: 0) {
                                ForEach(Priority.allCases) { p in
                                    PrioritySegmentDark(
                                        priority: p,
                                        isSelected: priority == p
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            priority = p
                                        }
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(2)
                        }

                        // ── Category ──────────────────────────────────────
                        GlassSection(title: "Category") {
                            GlassField {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 18)
                                    TextField("e.g. Work, Personal, Study", text: $category)
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        // ── Status (edit only) ────────────────────────────
                        if isEditing {
                            GlassSection(title: "Status") {
                                GlassField {
                                    Picker("Status", selection: $status) {
                                        ForEach(TaskStatus.allCases) { s in
                                            Label(s.label, systemImage: s.icon).tag(s)
                                        }
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                        }

                        // ── Delete (edit only) ────────────────────────────
                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Task", systemImage: "trash")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .glass(radius: 14, opacity: 0.03)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }

                        // Bottom padding for safe area
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(canSave ? .accentColor : .white.opacity(0.3))
                        .disabled(!canSave)
                }
            }
            .alert("Delete Task?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear { populate() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func populate() {
        guard let item = existingItem else { return }
        title      = item.title
        note       = item.note ?? ""
        hasDueDate = item.dueDate != nil
        dueDate    = item.dueDate ?? Date()
        priority   = item.priority
        status     = item.status
        category   = item.category ?? ""
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let optNote      = note.isEmpty     ? nil : note
        let optDue       = hasDueDate       ? dueDate : nil
        let optCategory  = category.isEmpty ? nil : category

        if isEditing, var updated = existingItem {
            updated.title    = trimmedTitle
            updated.note     = optNote
            updated.dueDate  = optDue
            updated.priority = priority
            updated.status   = status
            updated.category = optCategory
            viewModel.updateItem(updated)
        } else {
            viewModel.addItem(TodoItem(
                title:    trimmedTitle,
                note:     optNote,
                dueDate:  optDue,
                priority: priority,
                status:   .todo,
                category: optCategory
            ))
        }
        dismiss()
    }

    private func delete() {
        guard let id = existingItem?.id else { return }
        viewModel.deleteItem(id: id)
        dismiss()
    }
}

// MARK: - Glass Section Container

private struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.8)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .glass(radius: 14, opacity: 0.05)
        }
    }
}

// MARK: - Glass Field Row

private struct GlassField<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
    }
}

// MARK: - Glass Divider

private struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

// MARK: - Priority Segment (Dark)

private struct PrioritySegmentDark: View {
    let priority: Priority
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: priority.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(priority.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isSelected ? .white : priority.color.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [priority.color, priority.color.opacity(0.65)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: priority.color.opacity(0.45), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(priority.color.opacity(0.08))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
    }
}
