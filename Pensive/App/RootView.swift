import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel: AuthViewModel

    init(container: AppContainer) {
        _authViewModel = StateObject(wrappedValue: AuthViewModel(sessionStore: container.sessionStore))
    }

    var body: some View {
        Group {
            switch authViewModel.state {
            case .launching, .loadingSession:
                ProgressView("Checking session…")
                    .accessibilityIdentifier("auth_loading")

            case .unauthenticated, .authenticating:
                LoginView(viewModel: authViewModel)
                    .accessibilityIdentifier("login_view")

            case .authenticated(let session):
                AuthenticatedHomeView(userId: session.userId, signOut: authViewModel.signOut)
                    .accessibilityIdentifier("home_view")

            case .authError(let error):
                VStack(spacing: 12) {
                    Text("We couldn't verify your session")
                        .font(.headline)
                    Text(error.userMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        authViewModel.retrySessionCheck()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .accessibilityIdentifier("auth_error_view")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root_view")
        .task {
            authViewModel.bootstrapSessionIfNeeded()
        }
    }
}

private struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Pensive")
                .font(.largeTitle.weight(.semibold))

            Text("Sign in to continue")
                .foregroundStyle(.secondary)

            TextField("Email", text: $viewModel.email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("email_field")

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("password_field")

            if let inlineError = viewModel.inlineError, !inlineError.isEmpty {
                Text(inlineError)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("auth_inline_error")
            }

            Button {
                viewModel.signIn()
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("sign_in_button")
        }
        .padding()
    }
}

private struct AuthenticatedHomeView: View {
    let userId: String
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Pensive Home")
                .font(.title2)
            Text("Signed in as \(userId)")
                .foregroundStyle(.secondary)
                .font(.footnote)
            Button("Sign Out", action: signOut)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("sign_out_button")
        }
        .padding()
    }
}
