//
//  SettingsView.swift
//  ultraphotos
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showMetadata) private var showMetadata: Bool = true

    var body: some View {
        Form {
            Text("Settings")
                .font(.title2)
            Toggle("Show metadata", isOn: $showMetadata)
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 200)
    }
}
