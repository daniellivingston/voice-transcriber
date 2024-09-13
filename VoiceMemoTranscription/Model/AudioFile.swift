//
//  AudioFile.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import Foundation

struct AudioFile: Hashable, Codable, Identifiable {
    var id: Int
    var url: URL
    var name: String
    var date: Date
    var duration: Double // seconds
}
