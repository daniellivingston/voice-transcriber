//
//  AudioFileView.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import Foundation
import SwiftUI
import Speech

struct AudioFileDetail: View {
    @Binding var audioFile: AudioFile

    @State private var transcription: String = ""
    @State private var isTranscribing: Bool = false
    @State private var progress: Float = 0.0

    var body: some View {
        VStack {
            Text(audioFile.name)
                .font(.headline)

            AudioPlayerView(audioFile: audioFile)

            AudioTranscriptionView(audioFile: $audioFile)

            Spacer()

            /*
            if isTranscribing {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
                Text("Transcribing...")
            } else {
                Button("Start Transcription") {
                    startTranscription()
                }
                .disabled(isTranscribing)
            }

            ScrollView {
                Text(transcription)
                    .padding()
            }*/
        }
        .padding()
    }

    private func startTranscription() {
        print("[DRL] Transcription starting for \(audioFile.name)")
        isTranscribing = true
        progress = 0.0
        
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audioFile.url)
        
        recognizer?.recognitionTask(with: request) { (result, error) in
            guard let result = result else {
                print("Recognition failed with error: \(error?.localizedDescription ?? "Unknown error")")
                isTranscribing = false
                return
            }
            
            transcription = result.bestTranscription.formattedString
            progress = Float(result.bestTranscription.segments.count) / Float(result.bestTranscription.segments.last?.substringRange.location ?? 1)
            
            if result.isFinal {
                isTranscribing = false
                audioFile.transcription = transcription
                print("[DRL] Transcription complete for \(audioFile.name)")
            }
        }
    }
}

//#Preview("Sample #1") {
//    AudioFileView(landmark: landmarks[0])
//}
