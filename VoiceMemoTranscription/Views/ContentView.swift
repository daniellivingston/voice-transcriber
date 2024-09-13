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
    //@State private var audioFiles: [AudioFile] = []
    //@State private var selectedFile: AudioFile?
    //@State private var transcriptions: [UUID: String] = [:]
    //@State private var showErrorAlert: Bool = false
    //@State private var errorMessage: String = ""
    @State private var isSpeechRecognitionAuthorized = false
    
    // NEW
    @Environment(ModelData.self) var modelData
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
                ForEach(audioFiles) { audioFile in
                    NavigationLink {
                        AudioFileDetail(audioFile: audioFile)
                            .frame(minWidth: 300)
                    } label: {
                        AudioFileRow(audioFile: audioFile)
                    }
                    .tag(audioFile)
                }
            }
            .frame(minWidth: 300)
        } detail: {
            Text("Select an audio file")
                .frame(minWidth: 300)
        }
//        .focusedValue(\.selectedAudioFile, $modelData.audioFiles[index ?? 0])
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
//            requestDirectoryAccess()
            requestSpeechRecognitionAuthorization()
        }
//        .alert(isPresented: $showErrorAlert) {
//            Alert(
//                title: Text("Error"),
//                message: Text(errorMessage),
//                primaryButton: .default(Text("OK")),
//                secondaryButton: .destructive(Text("Quit")) {
//                    NSApplication.shared.terminate(nil)
//                }
//            )
//        }
    }

    private func requestSpeechRecognitionAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.isSpeechRecognitionAuthorized = authStatus == .authorized
            }
        }
    }

//    private func showError(_ message: String) {
//        errorMessage = message
//        showErrorAlert = true
//    }
    
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

struct WaveformView: View {
    let audioURL: URL
    @State private var samples: [Float] = []
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let middleY = height / 2
                let sampleCount = samples.count
                
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) / CGFloat(sampleCount) * width
                    let y = middleY + CGFloat(sample) * middleY
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 1)
            
            Path { path in
                let progress = CGFloat(currentTime / duration)
                let x = progress * geometry.size.width
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(Color.red, lineWidth: 2)
        }
        .onAppear(perform: loadAudioSamples)
    }
    
    private func loadAudioSamples() {
        guard let audioFile = try? AVAudioFile(forReading: audioURL) else { return }
        let format = audioFile.processingFormat
        let length = AVAudioFrameCount(audioFile.length)
        let sampleCount = 200 // Adjust this value to change the detail of the waveform
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length) else { return }
        do {
            try audioFile.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            
            let samplesPerSegment = Int(length) / sampleCount
            var loudestSamples: [Float] = []
            
            for i in 0..<sampleCount {
                let start = i * samplesPerSegment
                let end = min(start + samplesPerSegment, Int(length))
                var loudest: Float = 0
                
                for j in start..<end {
                    let sample = abs(channelData[Int(j)])
                    if sample > loudest {
                        loudest = sample
                    }
                }
                
                loudestSamples.append(loudest)
            }
            
            let maxSample = loudestSamples.max() ?? 1.0
            samples = loudestSamples.map { $0 / maxSample }
        } catch {
            print("Error reading audio file: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
