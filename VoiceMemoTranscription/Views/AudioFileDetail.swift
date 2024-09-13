//
//  AudioFileView.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import Foundation
import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - AudioPlayer

class AudioPlayer: ObservableObject {
    // Published properties to update the UI
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: AnyCancellable?
    
    // Load the audio file from the app bundle
    func loadAudio(_ audioFile: AudioFile) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile.url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Error setting up audio player: \(error.localizedDescription)")
        }
    }
    
    // Play or pause the audio
    func playPause() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    

    // Rewind by 5 seconds
    func rewind() {
        guard let player = audioPlayer else { return }
        player.currentTime = max(player.currentTime - 5, 0)
        currentTime = player.currentTime
    }
    
    // Forward by 5 seconds
    func forward() {
        guard let player = audioPlayer else { return }
        player.currentTime = min(player.currentTime + 5, duration)
        currentTime = player.currentTime
    }
    
    // Seek to a specific time
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = time
        currentTime = player.currentTime
    }
    
    // Start the timer to update currentTime
    private func startTimer() {
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
    }
    
    // Stop the timer
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    deinit {
        stopTimer()
    }
}

// MARK: - ContentView

struct AudioPlayerView: View {
    var audioFile: AudioFile
    @StateObject private var audioPlayer = AudioPlayer()

    private let skipButtonSize: CGFloat = 20
    private let playButtonSize: CGFloat = 30

    var body: some View {
        VStack {
            // Progress Bar and Time Labels
            VStack {
                // Progress Slider
                Slider(value: Binding(
                    get: {
                        audioPlayer.currentTime
                    },
                    set: { newValue in
                        audioPlayer.seek(to: newValue)
                    }
                ), in: 0...audioPlayer.duration)
                
                // Time Labels
                HStack {
                    Text(audioPlayer.currentTime.formattedTime)
                    Spacer()
                    Text(audioPlayer.duration.formattedTime)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                // Rewind Button
                Button(action: {
                    audioPlayer.rewind()
                }) {
                    Image(systemName: "gobackward.5")
                        .resizable()
                        .frame(width: skipButtonSize, height: skipButtonSize)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play/Pause Button
                Button(action: {
                    audioPlayer.playPause()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: playButtonSize, height: playButtonSize)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Forward Button
                Button(action: {
                    audioPlayer.forward()
                }) {
                    Image(systemName: "goforward.5")
                        .resizable()
                        .frame(width: skipButtonSize, height: skipButtonSize)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .onAppear {
            audioPlayer.loadAudio(audioFile)
        }
        .onDisappear {
            audioPlayer.stopAudio()
        }
        .frame(maxWidth: 500)
    }
}

// MARK: - Time Formatting Extension

extension TimeInterval {
    var formattedTime: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AudioFileDetail: View {
    var audioFile: AudioFile

    @State private var transcription: String = ""
    @State private var isTranscribing: Bool = false
    @State private var progress: Float = 0.0

    var body: some View {
        VStack {
            Text(audioFile.name)
                .font(.headline)

            AudioPlayerView(audioFile: audioFile)

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
