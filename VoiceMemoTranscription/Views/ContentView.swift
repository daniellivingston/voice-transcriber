//
//  ContentView.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 8/1/24.
//

import SwiftUI
import AVFoundation
import Security
import Speech

struct ContentView: View {
    @Environment(ModelData.self) var modelData
    @State private var isSpeechRecognitionAuthorized = false
    @State private var selectedAudioFile: AudioFile?

    var audioFiles: [AudioFile] {
        modelData.audioFiles
    }
    
    var index: Int? {
        modelData.audioFiles.firstIndex(where: { $0.id == selectedAudioFile?.id })
    }

    var body: some View {
        @Bindable var modelData = modelData

        NavigationSplitView {
            List(selection: $selectedAudioFile) {
                ForEach($modelData.audioFiles) { $audioFile in
                    NavigationLink {
                        AudioFileDetail(audioFile: $audioFile)
                            .frame(minWidth: 300)
                    } label: {
                        AudioFileRow(audioFile: $audioFile)
                    }
                    .tag(audioFile)
                }
            }
            .frame(minWidth: 300)
        } detail: {
            Text("Select an audio file")
                .frame(minWidth: 300)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: openVoiceMemoDirectory) {
                    Label("Open in Finder", systemImage: "folder")
                }
                Button(action: openSettingsWindow) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onAppear {
            requestSpeechRecognitionAuthorization()
        }
    }

    private func requestSpeechRecognitionAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.isSpeechRecognitionAuthorized = authStatus == .authorized
            }
        }
    }

    private func openVoiceMemoDirectory() {
        let url = URL(fileURLWithPath: VoiceMemoDirectory)
        NSWorkspace.shared.open(url)
    }
}

private func openSettingsWindow() {
    if let existingWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
        existingWindow.makeKeyAndOrderFront(nil)
    } else {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Settings"
        settingsWindow.center()
        settingsWindow.isReleasedWhenClosed = false

        let tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar

        let generalTab = NSHostingController(rootView: GeneralSettingsView())
        generalTab.title = "General"

        tabViewController.addChild(generalTab)

        // Set the icon for the General tab
        if let generalTabViewItem = tabViewController.tabViewItems.first {
            generalTabViewItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General Settings")
        }

        settingsWindow.contentViewController = tabViewController
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("openAIAPIKey") private var openAIAPIKey: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Section(header: Text("Accounts")) {
                    SecureField("OpenAI API Key", text: $openAIAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 300)

                    // Text("Your API key is stored securely in the app's preferences.")
                    //    .font(.caption)
                    //    .foregroundColor(.secondary)
                }
            }
            .padding()

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
