//
//  EditProfileView.swift
//  informed

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        List {
            NavigationLink(destination: ChangeUsernameView()) {
                MenuRow(
                    icon: "person.crop.circle",
                    title: "Change Username",
                    color: .secondary
                )
            }
            .listRowInsets(EdgeInsets())

            if userManager.hasPassword {
                NavigationLink(destination: ChangePasswordView()) {
                    MenuRow(
                        icon: "lock.rotation",
                        title: "Change Password",
                        color: .secondary
                    )
                }
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
