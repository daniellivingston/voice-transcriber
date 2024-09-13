//
//  AudioFile.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import Foundation

struct AudioFile: Hashable, Codable, Identifiable { //Identifiable, Hashable {
    //let id: URL
    var id = UUID()
    var url: URL
    var name: String
    var date: Date
    
    //func hash(into hasher: inout Hasher) {
        //hasher.combine(id)
    //}
    
    //static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
    //    return lhs.id == rhs.id
    //}
}
