//
//  ContentView.swift
//  faw2
//
import SwiftUI

// MARK: - Design Tokens

private extension Color {
    static let bgDark  = Color(red: 0.06, green: 0.06, blue: 0.14)
    static let bgDeep  = Color(red: 0.08, green: 0.04, blue: 0.20)
    static let bgMid   = Color(red: 0.05, green: 0.08, blue: 0.18)
}

// MARK: - Glass Modifier

struct GlassMaterial: ViewModifier {
    var cornerRadius: CGFloat = 16
    var baseOpacity: Double   = 0.06

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(baseOpacity))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glass(radius: CGFloat = 16, opacity: Double = 0.06) -> some View {
        modifier(GlassMaterial(cornerRadius: radius, baseOpacity: opacity))
    }
}

// MARK: - ContentView

struct ContentView: View {

    @EnvironmentObject private var viewModel: TaskViewModel
    @EnvironmentObject private var auth: AuthViewModel

    @State private var showAddTask        = false
    @State private var itemToEdit: TodoItem? = nil
    @State private var showSignOutAlert   = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background gradient ───────────────────────────────────
                LinearGradient(
                    colors: [.bgDark, .bgDeep, .bgMid],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {

                        // Stats
                        StatsHeaderView()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 14)

                        // Filter tabs
                        FilterTabsView()
                            .padding(.bottom, 10)

                        // Glass divider
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)

                        // Task list
                        if viewModel.isLoading && viewModel.items.isEmpty {
                            Spacer()
                            ProgressView("Loading…").tint(.white)
                            Spacer()
                        } else if viewModel.filteredItems.isEmpty {
                            TaskEmptyStateView(filter: viewModel.selectedFilter)
                        } else {
                            List {
                                ForEach(viewModel.filteredItems) { item in
                                    TaskCardView(item: item)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(
                                            top: 5, leading: 16,
                                            bottom: 5, trailing: 16
                                        ))
                                        .contentShape(Rectangle())
                                        .onTapGesture { itemToEdit = item }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                if let id = item.id { viewModel.deleteItem(id: id) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            let next = nextStatus(for: item)
                                            Button { viewModel.cycleStatus(for: item) } label: {
                                                Label(next.label, systemImage: next.icon)
                                            }
                                            .tint(next.color)
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }

                    // ── FAB ───────────────────────────────────────────────
                    Button { showAddTask = true } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .shadow(color: Color.accentColor.opacity(0.55), radius: 16, x: 0, y: 7)
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 22)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("My Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SearchBarButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSignOutAlert = true } label: {
                        Image(systemName: "person.circle")
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
            }
            .confirmationDialog(
                "Sign out of your account?",
                isPresented: $showSignOutAlert,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showAddTask) { AddEditTaskView() }
            .sheet(item: $itemToEdit) { item in AddEditTaskView(existingItem: item) }
        }
        .preferredColorScheme(.dark)
    }

    private func nextStatus(for item: TodoItem) -> TaskStatus {
        switch item.status {
        case .todo:       return .inProgress
        case .inProgress: return .done
        case .done:       return .todo
        }
    }
}

// MARK: - Search Bar

private struct SearchBarButton: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var isExpanded = false

    var body: some View {
        if isExpanded {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField("Search…", text: $viewModel.searchText)
                    .foregroundColor(.white)
                    .frame(width: 120)
                Button {
                    viewModel.searchText = ""
                    withAnimation { isExpanded = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            Button {
                withAnimation { isExpanded = true }
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }
}

// MARK: - Stats Header

private struct StatsHeaderView: View {
    @EnvironmentObject private var viewModel: TaskViewModel

    var body: some View {
        HStack(spacing: 10) {
            GlassStatPill(
                label: "Active", count: viewModel.activeCount,
                color: .accentColor, icon: "tray.full"
            )
            GlassStatPill(
                label: "Today",  count: viewModel.todayCount,
                color: .orange,   icon: "calendar"
            )
            GlassStatPill(
                label: "Done",   count: viewModel.doneCount,
                color: .green,    icon: "checkmark.circle"
            )
        }
    }
}

private struct GlassStatPill: View {
    let label: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text("\(count)")
                    .font(.title3.bold())
                    .contentTransition(.numericText())
            }
            .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glass(radius: 14, opacity: 0.05)
        .shadow(color: color.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Filter Tabs

private struct FilterTabsView: View {
    @EnvironmentObject private var viewModel: TaskViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct FilterChip: View {
    let filter: TaskFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(filter.rawValue, systemImage: filter.icon)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        } else {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Card

struct TaskCardView: View {
    let item: TodoItem
    @EnvironmentObject private var viewModel: TaskViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Priority strip
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [item.priority.color, item.priority.color.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 14)
                .padding(.leading, 14)

            HStack(alignment: .top, spacing: 12) {
                // Status toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.toggleDone(item)
                    }
                } label: {
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundColor(item.status.color)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    // Title + badge
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .strikethrough(item.status == .done, color: .white.opacity(0.35))
                            .foregroundColor(item.status == .done ? .white.opacity(0.35) : .white)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        PriorityBadge(priority: item.priority)
                    }

                    // Note
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }

                    // Meta row
                    HStack(spacing: 6) {
                        if let dateStr = item.formattedDueDate {
                            Label(dateStr, systemImage: "calendar")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(item.isOverdue ? .red : .white.opacity(0.45))
                        }
                        if let cat = item.category, !cat.isEmpty {
                            if item.formattedDueDate != nil {
                                Text("·")
                                    .foregroundColor(.white.opacity(0.25))
                                    .font(.caption2)
                            }
                            Label(cat, systemImage: "folder")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        if item.status != .done {
                            StatusChip(status: item.status)
                        }
                    }
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 14)
            .padding(.leading, 12)
            .padding(.trailing, 14)
        }
        .glass(radius: 16, opacity: 0.05)
        .shadow(
            color: item.priority.color.opacity(item.isOverdue ? 0.3 : 0.12),
            radius: 10, x: 0, y: 5
        )
    }

    private var statusIcon: String {
        switch item.status {
        case .todo:       return "circle"
        case .inProgress: return "clock.fill"
        case .done:       return "checkmark.circle.fill"
        }
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: priority.icon)
                .font(.system(size: 8, weight: .bold))
            Text(priority.label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.3)
        }
        .foregroundColor(priority.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(priority.color.opacity(0.18))
        .overlay(
            Capsule().stroke(priority.color.opacity(0.35), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let status: TaskStatus

    var body: some View {
        Label(status.label, systemImage: status.icon)
            .font(.caption2.weight(.medium))
            .foregroundColor(status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.15))
            .overlay(Capsule().stroke(status.color.opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - Empty State

private struct TaskEmptyStateView: View {
    let filter: TaskFilter

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 90, height: 90)
                Image(systemName: emptyIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.25))
            }
            VStack(spacing: 6) {
                Text(emptyTitle)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.55))
                Text(emptySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private var emptyIcon: String {
        switch filter {
        case .all:   return "checklist"
        case .today: return "calendar.badge.checkmark"
        case .done:  return "checkmark.seal"
        }
    }
    private var emptyTitle: String {
        switch filter {
        case .all:   return "No active tasks"
        case .today: return "Nothing due today"
        case .done:  return "No completed tasks"
        }
    }
    private var emptySubtitle: String {
        switch filter {
        case .all:   return "Tap + to add your first task"
        case .today: return "All caught up — enjoy your day!"
        case .done:  return "Finish a task to see it here"
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(TaskViewModel(userId: "preview"))
            .environmentObject(AuthViewModel())
    }
}
