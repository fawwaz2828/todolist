//
//  AuthView.swift
//  faw2
//
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var isLogin = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                        Text("My Tasks")
                            .font(.largeTitle.bold())
                        Text(isLogin ? "Masuk ke akunmu" : "Buat akun baru")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    if isLogin {
                        LoginForm()
                    } else {
                        SignUpForm()
                    }

                    // Toggle login/signup
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            isLogin.toggle()
                            auth.errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isLogin ? "Belum punya akun?" : "Sudah punya akun?")
                                .foregroundColor(.secondary)
                            Text(isLogin ? "Daftar" : "Masuk")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Login Form

private struct LoginForm: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showReset = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                AuthTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                AuthTextField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
            }
            .padding(.horizontal, 24)

            if let msg = auth.errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            AuthButton(title: "Masuk", isLoading: auth.isLoading) {
                Task { await auth.signIn(email: email, password: password) }
            }
            .padding(.horizontal, 24)

            Button("Lupa password?") { showReset = true }
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showReset) {
            ResetPasswordSheet()
        }
    }
}

// MARK: - Sign Up Form

private struct SignUpForm: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                AuthTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                AuthTextField(icon: "lock", placeholder: "Password (min. 6 karakter)", text: $password, isSecure: true)
                AuthTextField(icon: "lock.fill", placeholder: "Konfirmasi password", text: $confirmPassword, isSecure: true)

                if passwordMismatch {
                    Text("Password tidak cocok")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 24)

            if let msg = auth.errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            AuthButton(title: "Daftar", isLoading: auth.isLoading, disabled: passwordMismatch || password.count < 6) {
                Task { await auth.signUp(email: email, password: password) }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Reset Password Sheet

private struct ResetPasswordSheet: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Masukkan email kamu dan kami akan mengirimkan link untuk reset password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                AuthTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)

                if let msg = auth.errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(msg.contains("dikirim") ? .green : .red)
                        .multilineTextAlignment(.center)
                }

                AuthButton(title: "Kirim Email Reset", isLoading: auth.isLoading) {
                    Task { await auth.resetPassword(email: email) }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        auth.errorMessage = nil
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Shared Components

private struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct AuthButton: View {
    let title: String
    var isLoading = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(disabled || isLoading ? Color.accentColor.opacity(0.5) : Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled || isLoading)
    }
}

// MARK: - Preview

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
    }
}
