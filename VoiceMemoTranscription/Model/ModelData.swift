//
//  ModelData.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import Foundation
import SwiftUI
import SQLite3

@Observable
class ModelData {
    var audioFiles: [AudioFile] = []

    func initialize() {
        self.audioFiles = loadAudioFiles()
    }
}

let VoiceMemoDirectory = NSHomeDirectory() + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/"

private func loadAudioFiles() -> [AudioFile] {
    guard requestDirectoryAccess() else {
        let msg = "Access to Voice Memos directory is required for reading and transcribing audio files.\n\nPlease enable 'Full Disk Access' for this app under System Settings > Privacy & Security > Full Disk Access"
        showErrorAndQuit(message: msg)
        return []
    }

    print("[DRL] Loading files from \(VoiceMemoDirectory)...")
    return ParseVoiceMemosCloudRecordingsDatabase().sorted { $0.date > $1.date }
}

func ParseVoiceMemosCloudRecordingsDatabase() -> [AudioFile] {
    let homeDirectory = NSHomeDirectory()
    let dbPath = homeDirectory + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/CloudRecordings.db"

    var db: OpaquePointer?

    // Open the database
    if sqlite3_open(dbPath, &db) != SQLITE_OK {
        let msg = "Error opening SQLite database at \(dbPath)"
        showErrorAndQuit(message: msg)
        return []
    }

    defer {
        sqlite3_close(db)
    }

    var audioFiles: [AudioFile] = []

    // Prepare the SQL query using ZCLOUDRECORDING
    var queryStatement: OpaquePointer?
    let queryString = """
    SELECT Z_PK, ZDURATION, ZDATE, ZCUSTOMLABEL, ZENCRYPTEDTITLE, ZPATH FROM ZCLOUDRECORDING
    """

    if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
        // Execute the query and process each row
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            let id = sqlite3_column_int(queryStatement, 0)

            // Extract duration
            let duration = sqlite3_column_double(queryStatement, 1)

            // Extract and format date
            let dateInterval = sqlite3_column_double(queryStatement, 2)
            let date = Date(timeIntervalSinceReferenceDate: dateInterval)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            let dateString = dateFormatter.string(from: date)

            // Extract custom label (user-defined title)
            var customLabel = ""
            if let labelCStr = sqlite3_column_text(queryStatement, 3) {
                customLabel = String(cString: labelCStr)
            }

            // Extract encrypted title
            var encryptedTitle = ""
            if let encryptedTitleCStr = sqlite3_column_text(queryStatement, 4) {
                encryptedTitle = String(cString: encryptedTitleCStr)
            }

            // Extract file path
            var path = ""
            if let pathCStr = sqlite3_column_text(queryStatement, 5) {
                path = String(cString: pathCStr)
            }

            // Print out the metadata
            print("""
            ID: \(id)
            Custom Label: \(customLabel)
            Encrypted Title: \(encryptedTitle)
            Duration: \(String(format: "%.2f", duration)) seconds
            Date: \(dateString)
            Path: \(path)
            ------------------------------
            """)

            audioFiles.append(
                AudioFile(
                    id: Int(id),
                    url: URL(fileURLWithPath: VoiceMemoDirectory + path),
                    name: encryptedTitle,
                    date: date,
                    duration: duration
                )
            )
        }
        sqlite3_finalize(queryStatement)
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db))
        let msg = "Error preparing SQLite SELECT statement: \(errmsg)"
        showErrorAndQuit(message: msg)
    }

    return audioFiles
}

