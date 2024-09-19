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

struct MultiSelectionDetailView: View {
    let selectedIDs: [AudioFile.ID]
    @Environment(ModelData.self) var modelData
    
    var selectedAudioFiles: [AudioFile] {
        modelData.audioFiles.filter { selectedIDs.contains($0.id) }
    }
    
    var body: some View {
        VStack {
            Text("Multiple Audio Files Selected")
                .font(.headline)
            List(selectedAudioFiles) { audioFile in
                Text(audioFile.name) // Customize as needed
            }
            HStack {
                Button("Transcribe All") {
                    
                }
                Button("Save All") {
                    saveAllTranscriptions()
                }
            }
        }
        .padding()
    }

    private func saveAllTranscriptions() {
        let panel = NSOpenPanel()
        panel.title = "Select Directory to Save Transcriptions"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let directoryURL = panel.url {
            for audioFile in selectedAudioFiles {
                if let transcription = audioFile.transcription {
                    let sanitizedFileName = sanitizeFileName(audioFile.name) + ".txt"
                    let fileURL = directoryURL.appendingPathComponent(sanitizedFileName)

                    do {
                        try transcription.write(to: fileURL, atomically: true, encoding: .utf8)
                    } catch {
                        print("Error saving transcription for \(audioFile.name): \(error)")
                    }
                } else {
                    print("[DRL] Could not transcribe \(audioFile.name)")
                }
            }
        }
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

struct ContentView: View {
    @Environment(ModelData.self) var modelData
    @State private var isSpeechRecognitionAuthorized = false
    //@State private var selectedAudioFile: AudioFile?
    @State private var selectedAudioFiles = Set<AudioFile.ID>()

//    var audioFiles: [AudioFile] {
//        modelData.audioFiles
//    }
//    
//    var index: Int? {
//        modelData.audioFiles.firstIndex(where: { $0.id == selectedAudioFile?.id })
//    }

    var body: some View {
        @Bindable var modelData = modelData

        NavigationSplitView {
            List(selection: $selectedAudioFiles) {
                ForEach($modelData.audioFiles) { $audioFile in
                    AudioFileRow(audioFile: $audioFile)
                        .tag(audioFile.id)
                }
            }
            .frame(minWidth: 300)

//            List(selection: $selectedAudioFile) {
//                ForEach($modelData.audioFiles) { $audioFile in
//                    NavigationLink {
//                        AudioFileDetail(audioFile: $audioFile)
//                            .frame(minWidth: 300)
//                    } label: {
//                        AudioFileRow(audioFile: $audioFile)
//                    }
//                    .tag(audioFile)
//                }
//            }
//            .frame(minWidth: 300)
        } detail: {
            if selectedAudioFiles.count == 1 {
                if let selectedID = selectedAudioFiles.first,
                   let index = modelData.audioFiles.firstIndex(where: { $0.id == selectedID }) {
                    AudioFileDetail(audioFile: $modelData.audioFiles[index])
                        .frame(minWidth: 300)
                } else {
                    Text("Select an audio file")
                        .frame(minWidth: 300)
                }
            } else if selectedAudioFiles.count > 1 {
                MultiSelectionDetailView(selectedIDs: Array(selectedAudioFiles))
                    .frame(minWidth: 300)
            } else {
                Text("Select an audio file")
                    .frame(minWidth: 300)
            }
//            Text("Select an audio file")
//                .frame(minWidth: 300)
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
