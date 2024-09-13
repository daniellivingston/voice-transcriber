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

    tmp() // TEMP

    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: VoiceMemoDirectory),
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
            
        return fileURLs.filter { $0.pathExtension == "m4a" }
                       .compactMap { url -> AudioFile? in
                           guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                                 let modificationDate = attributes[.modificationDate] as? Date else {
                               return nil
                           }
                           return AudioFile(url: url, name: url.deletingPathExtension().lastPathComponent, date: modificationDate)
                       }
                       .sorted { $0.date > $1.date }
    } catch {
        //print("[DRL] Failed loading files: \(error.localizedDescription)")
        //showError("Failed to load files: \(error.localizedDescription)")
        fatalError("Failed to load files: \(error.localizedDescription)")
    }
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




// -------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------


private func tmp() {
    print(VoiceMemoDirectory)
    print(VoiceMemoDatabase)

    // printDatabaseOverview(atPath: VoiceMemoDatabase)
    // Call the function to list columns
    // listAllTablesAndColumns()
    print("---")
    parseVoiceMemosDatabase()
}

func parseVoiceMemosDatabase() {
    let homeDirectory = NSHomeDirectory()
    let dbPath = homeDirectory + "/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/CloudRecordings.db"

    var db: OpaquePointer?

    // Open the database
    if sqlite3_open(dbPath, &db) != SQLITE_OK {
        print("Error opening database at \(dbPath)")
        return
    }

    defer {
        sqlite3_close(db)
    }

    // Prepare the SQL query using ZCLOUDRECORDING
    var queryStatement: OpaquePointer?
    // let queryString = """
    // SELECT Z_PK, ZDURATION, ZDATE, ZCUSTOMLABEL, ZPATH FROM ZCLOUDRECORDING
    // """
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

            // Determine the title
            var title = customLabel
            if title.isEmpty {
                // Use the file name from the path as the title
                let fileName = (path as NSString).lastPathComponent
                title = (fileName as NSString).deletingPathExtension
                if title.isEmpty {
                    // Generate title based on date
                    title = "Recording \(dateString)"
                }
            }

            // Print out the metadata
            print("""
            ID: \(id)
            Title: \(title)
            Duration: \(String(format: "%.2f", duration)) seconds
            Date: \(dateString)
            Path: \(path)
            Encrypted Title: \(encryptedTitle)
            ------------------------------
            """)
        }
        sqlite3_finalize(queryStatement)
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db))
        print("Error preparing SELECT statement: \(errmsg)")
    }
}


func listColumns() {
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

    let queryString = "PRAGMA table_info(ZRECORDING);"
    var queryStatement: OpaquePointer?

    if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
        print("Columns in ZRECORDING table:")
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            if let columnNameCStr = sqlite3_column_text(queryStatement, 1) {
                let columnName = String(cString: columnNameCStr)
                print("- \(columnName)")
            }
        }
        sqlite3_finalize(queryStatement)
    } else {
        let errmsg = String(cString: sqlite3_errmsg(db))
        print("Error retrieving table info: \(errmsg)")
    }
}

func listAllTablesAndColumns() {
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


/// Prints an overview of the SQLite database at the given path.
/// The overview includes tables, their columns, row counts, and indexes.
/// - Parameter path: The file path to the SQLite database.
func printDatabaseOverview(atPath path: String) {
    var db: OpaquePointer?
    
    // Open the database in read-only mode
    if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
        if let errorPointer = sqlite3_errmsg(db) {
            let errorMessage = String(cString: errorPointer)
            print("❌ Unable to open database. Error: \(errorMessage)")
        } else {
            print("❌ Unable to open database. Unknown error.")
        }
        sqlite3_close(db)
        return
    }
    
    defer {
        sqlite3_close(db)
    }
    
    // Query to retrieve all user-defined table names
    let tableQuery = """
    SELECT name
    FROM sqlite_master
    WHERE type='table' AND name NOT LIKE 'sqlite_%';
    """
    var tableStmt: OpaquePointer?
    
    if sqlite3_prepare_v2(db, tableQuery, -1, &tableStmt, nil) != SQLITE_OK {
        if let errorPointer = sqlite3_errmsg(db) {
            let errorMessage = String(cString: errorPointer)
            print("❌ Failed to prepare table query. Error: \(errorMessage)")
        } else {
            print("❌ Failed to prepare table query. Unknown error.")
        }
        return
    }
    
    defer {
        sqlite3_finalize(tableStmt)
    }
    
    print("📂 **Database Overview:**\n")
    
    // Iterate through each table
    while sqlite3_step(tableStmt) == SQLITE_ROW {
        if let tableNameC = sqlite3_column_text(tableStmt, 0) {
            let tableName = String(cString: tableNameC)
            print("### Table: \(tableName)")
            
            // Fetch table schema information
            let schemaQuery = "PRAGMA table_info(\(escapeIdentifier(tableName)));"
            var schemaStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, schemaQuery, -1, &schemaStmt, nil) != SQLITE_OK {
                if let errorPointer = sqlite3_errmsg(db) {
                    let errorMessage = String(cString: errorPointer)
                    print("  ❌ Failed to get schema. Error: \(errorMessage)")
                } else {
                    print("  ❌ Failed to get schema. Unknown error.")
                }
                continue
            }
            
            defer {
                sqlite3_finalize(schemaStmt)
            }
            
            print("  **Columns:**")
            while sqlite3_step(schemaStmt) == SQLITE_ROW {
                // Column details
                let cid = sqlite3_column_int(schemaStmt, 0)
                if let nameC = sqlite3_column_text(schemaStmt, 1),
                   let typeC = sqlite3_column_text(schemaStmt, 2) {
                    let name = String(cString: nameC)
                    let type = String(cString: typeC)
                    print("    - \(name) (\(type))")
                }
            }
            
            // Get row count for the table
            let countQuery = "SELECT COUNT(*) FROM \(escapeIdentifier(tableName));"
            var countStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
                if sqlite3_step(countStmt) == SQLITE_ROW {
                    let count = sqlite3_column_int64(countStmt, 0)
                    print("  **Rows:** \(count)")
                } else {
                    print("  ❓ **Rows:** Unable to retrieve row count.")
                }
                sqlite3_finalize(countStmt)
            } else {
                print("  ❓ **Rows:** Could not prepare row count query.")
            }
            
            // Fetch indexes for the table
            let indexQuery = "PRAGMA index_list(\(escapeIdentifier(tableName)));"
            var indexStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, indexQuery, -1, &indexStmt, nil) == SQLITE_OK {
                print("  **Indexes:**")
                var hasIndexes = false
                while sqlite3_step(indexStmt) == SQLITE_ROW {
                    hasIndexes = true
                    if let indexNameC = sqlite3_column_text(indexStmt, 1) {
                        let indexName = String(cString: indexNameC)
                        print("    - \(indexName)")
                    }
                }
                if !hasIndexes {
                    print("    _No indexes found._")
                }
                sqlite3_finalize(indexStmt)
            } else {
                print("  ❓ **Indexes:** Could not prepare index list query.")
            }
            
            print("") // Add an empty line for better readability
        }
    }
}

/// Escapes SQLite identifiers (e.g., table names) to prevent SQL injection and handle special characters.
/// - Parameter identifier: The identifier to escape.
/// - Returns: A safely escaped identifier enclosed in double quotes.
func escapeIdentifier(_ identifier: String) -> String {
    // Escape double quotes by doubling them
    let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
    return "\"\(escaped)\""
}
