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

struct AudioFileRow: View {
    var audioFile: AudioFile
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(audioFile.name)
                .font(.headline)
            Text(audioFile.date, formatter: dateFormatter)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

