import SwiftUI

// MARK: - Authentication Models

struct UserRegistration: Codable {
    let username: String
    let email: String
    let password: String
}

struct UserResponse: Codable {
    let userId: String
    let username: String
    let email: String
    let sessionId: String
}

struct UserLogin: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let message: String
    let user: UserData
    
    struct UserData: Codable {
        let userID: String
        let username: String
        let email: String
        let sessionID: String
    }
}

// MARK: - API Functions

func createUser(_ registration: UserRegistration) async throws -> UserResponse {
    guard let url = URL(string: Config.Endpoints.createUser) else {
        throw URLError(.badURL)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(registration)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    
    let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
    return userResponse
}

func loginUser(_ login: UserLogin) async throws -> LoginResponse {
    guard let url = URL(string: Config.Endpoints.login) else {
        throw URLError(.badURL)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(login)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }
    
    if httpResponse.statusCode == 401 {
        throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"])
    }
    
    guard (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    
    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
    return loginResponse
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isLoginMode: Bool = true // Toggle between login and sign up
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showPassword: Bool = false
    @State private var showHowItWorks: Bool = false

    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, email, password, confirmPassword
    }
    
    var body: some View {
        ZStack {
            // Background gradient - adaptive
            Color.backgroundLight
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    Spacer().frame(height: 60)
                    
                    // Logo/Title Section
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.brandTeal, .brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Welcome to Informed")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(isLoginMode ? "Sign in to your account" : "Create your account to start fact-checking")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                    
                    // Form Card
                    VStack(spacing: 20) {
                        
                        // Username Field (Sign Up Only)
                        if !isLoginMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Username", systemImage: "person.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField("Enter username", text: $username)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .username)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .email
                                        }
                                    
                                    if !username.isEmpty {
                                        Image(systemName: username.count >= 3 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(username.count >= 3 ? .brandGreen : .brandRed)
                                    }
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(username.isEmpty ? Color.secondary.opacity(0.2) : (username.count >= 3 ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Enter email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                                
                                if !email.isEmpty {
                                    Image(systemName: isValidEmail(email) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isValidEmail(email) ? .brandGreen : .brandRed)
                                }
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(email.isEmpty ? Color.secondary.opacity(0.2) : (isValidEmail(email) ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Password", systemImage: "lock.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                if showPassword {
                                    TextField("Enter password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(isLoginMode ? .done : .next)
                                        .onSubmit {
                                            if isLoginMode {
                                                focusedField = nil
                                                if isFormValid {
                                                    login()
                                                }
                                            } else {
                                                focusedField = .confirmPassword
                                            }
                                        }
                                } else {
                                    SecureField("Enter password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(isLoginMode ? .done : .next)
                                        .onSubmit {
                                            if isLoginMode {
                                                focusedField = nil
                                                if isFormValid {
                                                    login()
                                                }
                                            } else {
                                                focusedField = .confirmPassword
                                            }
                                        }
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                                
                                if !password.isEmpty {
                                    Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(password.count >= 6 ? .brandGreen : .brandRed)
                                }
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(password.isEmpty ? Color.secondary.opacity(0.2) : (password.count >= 6 ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                            )
                            
                            if !password.isEmpty && password.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .font(.caption)
                                    .foregroundColor(.brandRed)
                            }
                        }
                        
                        // Confirm Password Field (Sign Up Only)
                        if !isLoginMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Confirm Password", systemImage: "lock.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if showPassword {
                                        TextField("Confirm password", text: $confirmPassword)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                focusedField = nil
                                                if isFormValid {
                                                    signUp()
                                                }
                                            }
                                    } else {
                                        SecureField("Confirm password", text: $confirmPassword)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                focusedField = nil
                                                if isFormValid {
                                                    signUp()
                                                }
                                            }
                                    }
                                    
                                    if !confirmPassword.isEmpty {
                                        Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(password == confirmPassword ? .brandGreen : .brandRed)
                                    }
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(confirmPassword.isEmpty ? Color.secondary.opacity(0.2) : (password == confirmPassword ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                                )
                                
                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("Passwords do not match")
                                        .font(.caption)
                                        .foregroundColor(.brandRed)
                                }
                            }
                        }
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.brandRed)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.brandRed)
                            }
                            .padding()
                            .background(Color.brandRed.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Submit Button
                        Button(action: isLoginMode ? login : signUp) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text(isLoginMode ? "Signing In..." : "Creating Account...")
                                } else {
                                    Image(systemName: isLoginMode ? "arrow.right.circle" : "person.badge.plus")
                                    Text(isLoginMode ? "Sign In" : "Create Account")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: isFormValid ? [.brandTeal, .brandBlue] : [.gray, .gray.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: isFormValid ? Color.brandBlue.opacity(0.3) : Color.clear, radius: 10, y: 5)
                        }
                        .disabled(!isFormValid || isLoading)
                        
                        // Toggle between Login and Sign Up
                        Button(action: {
                            isLoginMode.toggle()
                            errorMessage = nil
                            if !isLoginMode {
                                showHowItWorks = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isLoginMode ? "Don't have an account?" : "Already have an account?")
                                    .foregroundColor(.secondary)
                                Text(isLoginMode ? "Sign Up" : "Sign In")
                                    .foregroundColor(.brandBlue)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 8)
                        
                    }
                    .padding(24)
                    .background(Color.cardBackground)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 20, y: 10)
                    
                    Spacer()
                    
                }
                .padding(.horizontal, 20)
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .sheet(isPresented: $showHowItWorks) {
            HowItWorksSheet(isPresented: $showHowItWorks)
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        if isLoginMode {
            // Login only needs email and password
            return isValidEmail(email) && password.count >= 6
        } else {
            // Sign up needs all fields
            return username.count >= 3 &&
                   isValidEmail(email) &&
                   password.count >= 6 &&
                   password == confirmPassword
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Login Action
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loginRequest = UserLogin(
                    email: email,
                    password: password
                )
                
                let loginResponse = try await loginUser(loginRequest)
                
                // Save user data locally and session ID to keychain
                await MainActor.run {
                    userManager.saveUser(
                        userId: loginResponse.user.userID, 
                        username: loginResponse.user.username,
                        sessionId: loginResponse.user.sessionID
                    )
                    print("✅ User logged in successfully! ID: \(loginResponse.user.userID), Session: \(loginResponse.user.sessionID)")
                }
                
            } catch let error as NSError where error.code == 401 {
                await MainActor.run {
                    errorMessage = "Invalid email or password"
                    print("❌ Login error: Invalid credentials")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to login: \(error.localizedDescription)"
                    print("❌ Login error: \(error)")
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Sign Up Action
    
    private func signUp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let registration = UserRegistration(
                    username: username,
                    email: email,
                    password: password
                )
                
                let userResponse = try await createUser(registration)
                
                // Save user data locally and session ID to keychain
                await MainActor.run {
                    userManager.saveUser(
                        userId: userResponse.userId, 
                        username: userResponse.username,
                        sessionId: userResponse.sessionId
                    )
                    print("✅ User created successfully! ID: \(userResponse.userId), Session: \(userResponse.sessionId)")
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create account: \(error.localizedDescription)"
                    print("❌ Registration error: \(error)")
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - How It Works Sheet (shown on sign-up)

struct HowItWorksSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundLight.ignoresSafeArea()
                HowItWorksCarouselView {
                    isPresented = false
                }
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { isPresented = false }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(UserManager())
    }
}
