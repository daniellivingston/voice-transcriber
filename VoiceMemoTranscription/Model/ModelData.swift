//
//  ModelData.swift
//  VoiceMemoTranscription
//
//  Created by Daniel Livingston on 9/10/24.
//

import Foundation
import SwiftUI
import SQLite3

// TODO: Handle errors. Should not crash the app. Alert the user.

@Observable
class ModelData {
    var audioFiles: [AudioFile] = loadAudioFiles()
}

let VoiceMemoDirectory = NSHomeDirectory() + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/"
let VoiceMemoDatabase  = NSHomeDirectory() + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/CloudRecordings.db"


private func loadAudioFiles() -> [AudioFile] {
    guard requestDirectoryAccess() else { fatalError("Access to Voice Memos directory is required") }

    print("[DRL] Loading files from \(VoiceMemoDirectory)...")
    return ParseVoiceMemosCloudRecordingsDatabase().sorted { $0.date > $1.date }
}

private func requestDirectoryAccess() -> Bool {
    let url = URL(fileURLWithPath: VoiceMemoDirectory)

    do {
        // Attempt to access the directory
        _ = try FileManager.default.contentsOfDirectory(atPath: VoiceMemoDirectory)
        //isDirectoryAccessGranted = true
        //loadFiles()
        return true
    } catch {
        // If access is denied, prompt the user to grant access
        let openPanel = NSOpenPanel()
        openPanel.message = "Please grant access to the Voice Memos directory"
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = url
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false

        var granted = false
        openPanel.begin { response in
            if response == .OK {
                granted = true
                //self.isDirectoryAccessGranted = true
                //self.loadFiles()
            } else {
                //self.showError("Access to Voice Memos directory is required")
                fatalError("Access to Voice Memos directory is required")
            }
        }
        return granted
    }
}

func ParseVoiceMemosCloudRecordingsDatabase() -> [AudioFile] {
    let homeDirectory = NSHomeDirectory()
    let dbPath = homeDirectory + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/CloudRecordings.db"

    var db: OpaquePointer?

    // Open the database
    if sqlite3_open(dbPath, &db) != SQLITE_OK {
        print("Error opening database at \(dbPath)")
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
        print("Error preparing SELECT statement: \(errmsg)")
    }

    return audioFiles
}

private func listAllTablesAndColumns() {
    let homeDirectory = NSHomeDirectory()
    let dbPath = homeDirectory + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/CloudRecordings.db"

    var db: OpaquePointer?

    if sqlite3_open(dbPath, &db) != SQLITE_OK {
        print("Error opening database at \(dbPath)")
        return
    }

    defer {
        sqlite3_close(db)
    }

    let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table';"
    var tablesStatement: OpaquePointer?

    if sqlite3_prepare_v2(db, tablesQuery, -1, &tablesStatement, nil) == SQLITE_OK {
        print("Tables and their columns:")
        while sqlite3_step(tablesStatement) == SQLITE_ROW {
            if let tableNameCStr = sqlite3_column_text(tablesStatement, 0) {
                let tableName = String(cString: tableNameCStr)
                print("\nTable: \(tableName)")

                // Get columns for this table
                let columnsQuery = "PRAGMA table_info(\(tableName));"
                var columnsStatement: OpaquePointer?

                if sqlite3_prepare_v2(db, columnsQuery, -1, &columnsStatement, nil) == SQLITE_OK {
                    while sqlite3_step(columnsStatement) == SQLITE_ROW {
                        if let columnNameCStr = sqlite3_column_text(columnsStatement, 1) {
                            let columnName = String(cString: columnNameCStr)
                            print("- \(columnName)")
                        }
                    }
                    sqlite3_finalize(columnsStatement)
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    print("Error retrieving columns for table \(tableName): \(errmsg)")
                }
            }
        }
        sqlite3_finalize(tablesStatement)
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db))
        print("Error retrieving table names: \(errmsg)")
    }
}
