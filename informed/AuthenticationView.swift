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
}

// MARK: - User Defaults Manager (for storing userId)

class UserManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?
    @Published var currentUsername: String?
    
    private let userIdKey = "stored_user_id"
    private let usernameKey = "stored_username"
    
    init() {
        loadStoredUser()
    }
    
    func loadStoredUser() {
        if let userId = UserDefaults.standard.string(forKey: userIdKey),
           let username = UserDefaults.standard.string(forKey: usernameKey) {
            self.currentUserId = userId
            self.currentUsername = username
            self.isAuthenticated = true
        }
    }
    
    func saveUser(userId: String, username: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        self.currentUserId = userId
        self.currentUsername = username
        self.isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        self.currentUserId = nil
        self.currentUsername = nil
        self.isAuthenticated = false
    }
}

// MARK: - API Functions

func createUser(_ registration: UserRegistration) async throws -> UserResponse {
    guard let url = URL(string: "http://localhost:5001/create-user") else {
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

// MARK: - Authentication View

struct AuthenticationView: View {
    @EnvironmentObject var userManager: UserManager
    
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showPassword: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.brandBlue.opacity(0.1), Color.brandTeal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                        
                        Text("Create your account to start fact-checking")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                    
                    // Form Card
                    VStack(spacing: 20) {
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Username", systemImage: "person.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            HStack {
                                TextField("Enter username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                
                                if !username.isEmpty {
                                    Image(systemName: username.count >= 3 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(username.count >= 3 ? .brandGreen : .brandRed)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(username.isEmpty ? Color.gray.opacity(0.2) : (username.count >= 3 ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                            )
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            HStack {
                                TextField("Enter email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                
                                if !email.isEmpty {
                                    Image(systemName: isValidEmail(email) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isValidEmail(email) ? .brandGreen : .brandRed)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(email.isEmpty ? Color.gray.opacity(0.2) : (isValidEmail(email) ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Password", systemImage: "lock.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            HStack {
                                if showPassword {
                                    TextField("Enter password", text: $password)
                                } else {
                                    SecureField("Enter password", text: $password)
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                }
                                
                                if !password.isEmpty {
                                    Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(password.count >= 6 ? .brandGreen : .brandRed)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(password.isEmpty ? Color.gray.opacity(0.2) : (password.count >= 6 ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                            )
                            
                            if !password.isEmpty && password.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .font(.caption)
                                    .foregroundColor(.brandRed)
                            }
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Confirm Password", systemImage: "lock.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            HStack {
                                if showPassword {
                                    TextField("Confirm password", text: $confirmPassword)
                                } else {
                                    SecureField("Confirm password", text: $confirmPassword)
                                }
                                
                                if !confirmPassword.isEmpty {
                                    Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(password == confirmPassword ? .brandGreen : .brandRed)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(confirmPassword.isEmpty ? Color.gray.opacity(0.2) : (password == confirmPassword ? Color.brandGreen : Color.brandRed), lineWidth: 1)
                            )
                            
                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords do not match")
                                    .font(.caption)
                                    .foregroundColor(.brandRed)
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
                        
                        // Sign Up Button
                        Button(action: signUp) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Creating Account...")
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("Create Account")
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
                        
                    }
                    .padding(24)
                    .background(Color.backgroundLight)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
                    
                    Spacer()
                    
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        username.count >= 3 &&
        isValidEmail(email) &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
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
                
                // Save user data locally
                await MainActor.run {
                    userManager.saveUser(userId: userResponse.userId, username: userResponse.username)
                    print("✅ User created successfully! ID: \(userResponse.userId)")
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

// MARK: - Preview

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(UserManager())
    }
}
