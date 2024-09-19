//
//  TranscriptionManager.swift
//  Josh Smells Like Used Socks
//
//  Created by Daniel Livingston on 9/19/24.
//

import Foundation
import UniformTypeIdentifiers

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

/// Enum for transcription errors.
enum TranscriptionError: Error {
    case fileNotFound(String)
    case apiError(String)
    case unexpectedServerResponse(Int)
    case other(Error)
}

/// Transcribes the audio file using OpenAI's Whisper model.
/// - Parameters:
///   - fileURL: The URL of the audio file to transcribe.
///   - apiKey: Your OpenAI API key.
/// - Returns: The transcription text.
/// - Throws: An error if the transcription fails.
func transcribeAudio(fileURL: URL, apiKey: String) async throws -> String {
    // Ensure the file exists at the given path
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw TranscriptionError.fileNotFound(fileURL.path)
    }
    
    // Prepare the API request
    let apiURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    var request = URLRequest(url: apiURL)
    request.httpMethod = "POST"
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
                    throw TranscriptionError.apiError(apiError.error.message)
                } else {
                    throw TranscriptionError.unexpectedServerResponse(httpResponse.statusCode)
                }
            }
        }
        
        // Decode the successful transcription response
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return transcriptionResponse.text
    } catch {
        throw TranscriptionError.other(error)
    }
}

/// Creates the multipart/form-data body for the HTTP request.
/// - Parameters:
///   - fileURL: The URL of the audio file to upload.
///   - boundary: The boundary string used to separate parts in the multipart data.
/// - Returns: The constructed multipart/form-data as Data.
func createMultipartBody(fileURL: URL, boundary: String) -> Data {
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
func mimeTypeForPath(path: String) -> String {
    let url = NSURL(fileURLWithPath: path)
    let pathExtension = url.pathExtension ?? ""
    
    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
       let mimeTypeCF = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
        return mimeTypeCF as String
    }
    
    // Default MIME type if unable to determine
    return "application/octet-stream"
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
