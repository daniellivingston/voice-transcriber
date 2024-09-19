//
//  TranscriptionView.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/13/24.
//

import Foundation
import SwiftUI

struct AudioTranscriptionView: View {
    @AppStorage("openAIAPIKey") private var openAIAPIKey: String = ""
    @Binding var audioFile: AudioFile
    
    var filePath: String {
        audioFile.url.path
    }
    
    // State variables to manage UI updates
    @State private var transcriptionText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                // Show a loading indicator while transcribing
                ProgressView("Transcribing audio...")
            } else if let error = errorMessage {
                // Display error messages if any
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            } else {
                // Display the transcription result
                if let transcription = audioFile.transcription {
                    VStack {
                        ScrollView {
                            Text(transcription)
                                .textSelection(.enabled)
                                .padding()
                            
                            HStack {
                                Spacer()
                                
                                Button("Copy") {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.declareTypes([.string], owner: nil)
                                    pasteboard.setString(transcription, forType: .string)
                                }
                                Button("Save") {
                                    SaveAudioFile()
                                }
                            }
                        }
                    }
                } else {
                    Text("No transcription available.")
                }
            }
            
            Button("Transcribe") {
                Task {
                    await startTranscription()
                }
            }
            .disabled(isLoading)
        }
        .padding()
    }
    
    private func SaveAudioFile() {
        guard let transcription = audioFile.transcription else {
            print("No transcription available to save.")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(audioFile.name)_transcription.txt"
        
        savePanel.beginSheetModal(for: NSApp.keyWindow!) { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try transcription.write(to: url, atomically: true, encoding: .utf8)
                    print("Transcription saved to file: \(url.path)")
                } catch {
                    print("Error saving transcription: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func startTranscription() async {
        self.isLoading = true
        self.errorMessage = nil
        self.transcriptionText = ""
        
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            let transcription = try await transcribeAudio(fileURL: fileURL, apiKey: openAIAPIKey)
            self.transcriptionText = transcription
            self.isLoading = false
            self.audioFile.transcription = transcription
            print("[DRL] Transcription complete for \(filePath)")
            print("[DRL] Transcription: \(transcription)")
        } catch let error as TranscriptionError {
            self.isLoading = false
            switch error {
                case .fileNotFound(let path):
                    self.errorMessage = "Audio file not found at path: \(path)"
                case .apiError(let message):
                    self.errorMessage = message
                case .unexpectedServerResponse(let statusCode):
                    self.errorMessage = "Unexpected server response: \(statusCode)"
                case .other(let underlyingError):
                    self.errorMessage = underlyingError.localizedDescription
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
}
