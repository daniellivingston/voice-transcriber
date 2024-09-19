//
//  VoiceMemoTranscriptionApp.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 8/1/24.
//

import SwiftUI


@main
struct VoiceMemoTranscriptionApp: App {
    @State private var modelData = ModelData()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(modelData)
        }

       Settings {
           GeneralSettingsView()
       }
    }
}
