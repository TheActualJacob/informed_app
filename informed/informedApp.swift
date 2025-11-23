//
//  informedApp.swift
//  informed
//
//  Created by Jacob Ryan on 11/22/25.
//

import SwiftUI

@main
struct informedApp: App {
    @StateObject private var userManager = UserManager()
    
    init() {
        // 🧪 TEMPORARY: Clear stored credentials to test sign-up
        // Remove this after testing!
        UserDefaults.standard.removeObject(forKey: "stored_user_id")
        UserDefaults.standard.removeObject(forKey: "stored_username")
    }
    
    var body: some Scene {
        WindowGroup {
            if userManager.isAuthenticated {
                ContentView()
                    .environmentObject(userManager)
            } else {
                AuthenticationView()
                    .environmentObject(userManager)
            }
        }
    }
}
