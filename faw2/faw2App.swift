//
//  faw2App.swift
//  faw2
//
import SwiftUI
import FirebaseCore

@main
struct faw2App: App {
    @StateObject private var todoStore: TodoStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
        _todoStore = StateObject(wrappedValue: TodoStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(todoStore)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .inactive || phase == .background {
                todoStore.flushToDisk()
            }
        }
    }
}
