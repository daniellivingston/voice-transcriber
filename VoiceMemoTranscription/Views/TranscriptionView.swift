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
                    await transcribeAudio()
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
    
    /// Transcribes the audio file using OpenAI's Whisper model.
    private func transcribeAudio() async {
        print("[DRL] Transcription starting for \(audioFile.name)")
        print("[DRL] Reading file at \(filePath)")
              
        // Ensure the file exists at the given path
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            DispatchQueue.main.async {
                self.errorMessage = "Audio file not found at path: \(filePath)"
            }
            return
        }
        
        // Update UI to show loading state
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.transcriptionText = ""
        }
        
        // Prepare the API request
        let apiURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        
        // Replace with your actual OpenAI API key
        let apiKey = openAIAPIKey//"YOUR_OPENAI_API_KEY"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Generate a unique boundary string using a UUID
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Construct the multipart form data
        let httpBody = createMultipartBody(fileURL: fileURL, boundary: boundary)
        request.httpBody = httpBody
        
        do {
            // Perform the network request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Attempt to decode error message from API
                    if let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                        DispatchQueue.main.async {
                            self.errorMessage = apiError.error.message
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Unexpected server response: \(httpResponse.statusCode)"
                        }
                    }
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
            }
            
            // Decode the successful transcription response
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            
            // Update the UI with the transcription text
            DispatchQueue.main.async {
                self.transcriptionText = transcriptionResponse.text
                self.isLoading = false
                self.audioFile.transcription = transcriptionResponse.text

                print("[DRL] Transcription complete for \(self.filePath)")
                print("[DRL] Transcription: \(self.audioFile.transcription ?? "None")")
            }
        } catch {
            // Handle and display any errors that occurred during the request
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Creates the multipart/form-data body for the HTTP request.
    /// - Parameters:
    ///   - fileURL: The URL of the audio file to upload.
    ///   - boundary: The boundary string used to separate parts in the multipart data.
    /// - Returns: The constructed multipart/form-data as Data.
    private func createMultipartBody(fileURL: URL, boundary: String) -> Data {
        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeForPath(path: fileURL.path)
        
        // Add the "model" field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")
        
        // Add the "file" field with the audio data
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        
        if let fileData = try? Data(contentsOf: fileURL) {
            body.append(fileData)
            body.append("\r\n")
        }
        
        // Close the multipart form data
        body.append("--\(boundary)--\r\n")
        
        return body
    }
    
    /// Determines the MIME type based on the file extension.
    /// - Parameter path: The file path.
    /// - Returns: The corresponding MIME type as a String.
    private func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension ?? ""
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
           let mimeTypeCF = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
            return mimeTypeCF as String
        }
        
        // Default MIME type if unable to determine
        return "application/octet-stream"
    }
}

// MARK: - Models for Decoding API Responses

/// Represents a successful transcription response from OpenAI.
struct TranscriptionResponse: Codable {
    let text: String
}

/// Represents an error response from OpenAI.
struct OpenAIErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String
        let param: String?
        let code: String?
    }
    
    let error: ErrorDetail
}

// MARK: - Data Extension for Multipart Form Data

extension Data {
    /// Appends a string to the Data using UTF-8 encoding.
    /// - Parameter string: The string to append.
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Preview

//struct AudioTranscriptionView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Replace with a valid file path on your device for testing
//        AudioTranscriptionView(filePath: "/path/to/your/audiofile.m4a")
//    }
//}
