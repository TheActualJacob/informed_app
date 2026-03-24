//
//  EditProfileView.swift
//  informed

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                NavigationLink(destination: ChangeUsernameView()) {
                    MenuRow(
                        icon: "person.crop.circle",
                        title: "Change Username",
                        color: .secondary
                    )
                }

                if userManager.hasPassword {
                    Divider().padding(.leading, 60)
                    NavigationLink(destination: ChangePasswordView()) {
                        MenuRow(
                            icon: "lock.rotation",
                            title: "Change Password",
                            color: .secondary
                        )
                    }
                }
            }
            .background(Color.cardBackground)
            .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
            .shadow(color: .black.opacity(0.05), radius: Theme.Shadow.sm, y: 2)
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.xl)
        }
        .background(Color.backgroundLight)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
