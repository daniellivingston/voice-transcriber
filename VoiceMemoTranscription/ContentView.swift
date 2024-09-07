//
//  ContentView.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 8/1/24.
//

import SwiftUI
import Speech
import Security

let VoiceMemoDirectory = "/Users/livingston/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/"

struct FileMetadataView: View {
    var file: URL
    var isAuthorized: Bool

    @State private var transcription: String = "Transcription will appear here."
    @State private var isProcessing: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("File Metadata")
                .font(.headline)
                .padding(.bottom)

            Text("Path: \(file.path)")
            Text("Name: \(file.lastPathComponent)")
            Text("Size: \(fileSize()) bytes")
            Text("Created: \(fileCreationDate() ?? Date(), formatter: dateFormatter)")
            Text("Modified: \(fileModificationDate() ?? Date(), formatter: dateFormatter)")
            
            Spacer()
            
            Text(transcription)
                .padding()
            
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else {
                Button("Start Transcription") {
                    startTranscription()
                }
                .disabled(!isAuthorized)
                .padding()
            }
            
            Spacer()
            
            Button(action: { startTranscription() }) {
                Text("Transcribe")
            }
        }
        .padding()
    }

    func fileSize() -> Int64 {
        if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return Int64(fileSize)
        }
        return 0
    }
    
    func fileCreationDate() -> Date? {
        if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate {
            return creationDate
        }
        return nil
    }
    
    func fileModificationDate() -> Date? {
        if let modificationDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            return modificationDate
        }
        return nil
    }

    func startTranscription() {
        isProcessing = true

        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: file)

        speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                if let error = error {
                    self.transcription = "There was an error: \(error.localizedDescription)"
                } else if let result = result {
                    self.transcription = result.bestTranscription.formattedString
                }
            }
        }
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct ContentView: View {
    @State private var audioFiles: [AudioFile] = []
    @State private var selectedFile: AudioFile?
    @State private var isAuthorized: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isDirectoryAccessGranted = false

    var body: some View {
        NavigationView {
            List(audioFiles, id: \.self, selection: $selectedFile) { file in
                VStack(alignment: .leading) {
                    Text(file.name)
                        .font(.headline)
                    Text(file.date, formatter: dateFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 200)
            .onAppear(perform: loadFiles)

            if let selectedFile = selectedFile {
                FileMetadataView(file: selectedFile.url, isAuthorized: isAuthorized)
                    .frame(minWidth: 300)
            } else {
                Text("Select a file to see metadata")
                    .frame(minWidth: 300)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { print("clicked") }) {
                    Label("Files", systemImage: "doc.text")
                }
                Button(action: openVoiceMemoDirectory) {
                    Label("Open in Finder", systemImage: "folder")
                }
                Button(action: { print("clicked") }) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onAppear {
            requestDirectoryAccess()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                primaryButton: .default(Text("OK")),
                secondaryButton: .destructive(Text("Quit")) {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
    }

    private func requestDirectoryAccess() {
        let url = URL(fileURLWithPath: VoiceMemoDirectory)
        do {
            // Attempt to access the directory
            _ = try FileManager.default.contentsOfDirectory(atPath: VoiceMemoDirectory)
            isDirectoryAccessGranted = true
            loadFiles()
        } catch {
            // If access is denied, prompt the user to grant access
            let openPanel = NSOpenPanel()
            openPanel.message = "Please grant access to the Voice Memos directory"
            openPanel.prompt = "Grant Access"
            openPanel.directoryURL = url
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            
            openPanel.begin { response in
                if response == .OK {
                    self.isDirectoryAccessGranted = true
                    self.loadFiles()
                } else {
                    self.showError("Access to Voice Memos directory is required")
                }
            }
        }
    }

    private func loadFiles() {
        guard isDirectoryAccessGranted else { return }
        
        print("[DRL] Loading files from \(VoiceMemoDirectory)...")

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: VoiceMemoDirectory), includingPropertiesForKeys: [.contentModificationDateKey])
            
            self.audioFiles = fileURLs.filter { $0.pathExtension == "m4a" }
                .compactMap { url -> AudioFile? in
                    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                          let modificationDate = attributes[.modificationDate] as? Date else {
                        return nil
                    }
                    return AudioFile(url: url, name: url.deletingPathExtension().lastPathComponent, date: modificationDate)
                }
                .sorted { $0.date > $1.date }
        } catch {
            print("[DRL] Failed loading files: \(error.localizedDescription)")
            showError("Failed to load files: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    private func openVoiceMemoDirectory() {
        let url = URL(fileURLWithPath: VoiceMemoDirectory)
        NSWorkspace.shared.open(url)
    }
}

struct AudioFile: Identifiable, Hashable {
    //let id: URL
    let id = UUID()
    let url: URL
    let name: String
    let date: Date
    
    //func hash(into hasher: inout Hasher) {
        //hasher.combine(id)
    //}
    
    //static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
    //    return lhs.id == rhs.id
    //}
}

#Preview {
    ContentView()
}
