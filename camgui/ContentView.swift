//
//  ContentView.swift
//  camgui
//
//  Created by Peter Richardson on 7/4/25.
//

import CamviewCore  // re-exports Protect
import SwiftUI

struct ContentView: View {
    @State private var cameras: [Camera] = []
    @State private var errorText: String?

    var body: some View {
        NavigationSplitView {
            CameraListView(cameras: $cameras)
                .navigationTitle("Cameras")
        } detail: {
            if let errorText {
                // A missing API key is the expected first-run state, not a crash.
                ContentUnavailableView(
                    "Can't reach Protect",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorText))
            } else {
                Text("Select a camera")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            do {
                let config = try Configuration()
                let protect = ProtectService(host: config.host, apiKey: config.apiKey)
                cameras = try await protect.cameras()
            } catch {
                errorText = String(describing: error)
            }
        }
    }
}
