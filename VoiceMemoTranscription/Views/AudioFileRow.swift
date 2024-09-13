//
//  AudioFileRow.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import SwiftUI

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

func formatSeconds(_ totalSeconds: Double) -> String {
    let totalSecondsRounded = Int(totalSeconds)
    let minutes = totalSecondsRounded / 60
    let seconds = totalSecondsRounded % 60
    return String(format: "%d:%02d", minutes, seconds)
}

struct AudioFileRow: View {
    var audioFile: AudioFile
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(audioFile.name)
                .font(.headline)
            HStack {
                Text(audioFile.date, formatter: dateFormatter)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatSeconds(audioFile.duration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

