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
    var audioFile: AudioFile

    @State private var transcription: String = ""
    @State private var isTranscribing: Bool = false
    @State private var progress: Float = 0.0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0

    var body: some View {
        VStack {
            Text(audioFile.name)
                .font(.headline)
            
            // Waveform view
            // WaveformView(audioURL: audioFile.url, currentTime: $currentTime, duration: duration)
            //    .frame(height: 100)
            //    .padding()
            
            // Audio player controls
            HStack {
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                }
                
                Slider(value: $currentTime, in: 0...duration, onEditingChanged: sliderEditingChanged)
                    .disabled(duration == 0)
                
                Text(formatTime(currentTime))
                    + Text(" / ")
                    + Text(formatTime(duration))
            }
            .padding()
            
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
            }
        }
        .padding()
        .onAppear(perform: setupAudioPlayer)
        .onDisappear(perform: stopAudio)
    }
    
    private func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile.url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Error setting up audio player: \(error.localizedDescription)")
        }
    }
    
    private func togglePlayPause() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
            startPlaybackTimer()
        }
        isPlaying.toggle()
    }
    
    private func startPlaybackTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if let player = audioPlayer {
                currentTime = player.currentTime
                if !player.isPlaying {
                    timer.invalidate()
                    isPlaying = false
                }
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func sliderEditingChanged(editingStarted: Bool) {
        if !editingStarted {
            audioPlayer?.currentTime = currentTime
            if !isPlaying {
                audioPlayer?.play()
                isPlaying = true
                startPlaybackTimer()
            }
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startTranscription() {
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
            }
        }
    }
}

//#Preview("Sample #1") {
//    AudioFileView(landmark: landmarks[0])
//}
