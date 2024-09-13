//
//  VoiceMemoSettings.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import SwiftUI

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case whisper = "Whisper (OpenAI)"
    case speech = "Speech (Apple)"

    var id: TranscriptionProvider {
        return self
    }
}


struct VoiceMemoSettings: View {
    @AppStorage("VoiceTranscription.transcriber")
    private var transcriber: TranscriptionProvider = .speech
    
    var body: some View {
        Form {
            Picker("Transcription Provider:", selection: $transcriber) {
                ForEach(TranscriptionProvider.allCases) { provider in
                    Text(provider.rawValue)
                }
            }
            .pickerStyle(.inline)
        }
        .frame(width: 300)
        .navigationTitle("Voice Memo Settings")
        .padding(80)
    }
}

#Preview {
    VoiceMemoSettings()
}
