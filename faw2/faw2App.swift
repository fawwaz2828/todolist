//
//  faw2App.swift
//  faw2
//
import SwiftUI
import FirebaseCore

@main
struct faw2App: App {
    @StateObject private var auth = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}

// MARK: - Root: routes between Auth and main app

private struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        if auth.isLoggedIn, let uid = auth.user?.uid {
            LoggedInView(userId: uid)
        } else {
            AuthView()
        }
    }
}

// MARK: - Logged-in wrapper: creates TaskViewModel once per session

private struct LoggedInView: View {
    @StateObject private var viewModel: TaskViewModel

    init(userId: String) {
        _viewModel = StateObject(wrappedValue: TaskViewModel(userId: userId))
    }

    var body: some View {
        ContentView()
            .environmentObject(viewModel)
    }
}
