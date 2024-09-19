//
//  DirectoryAccess.swift
//  Josh Smells Like Used Socks
//
//  Created by Daniel Livingston on 9/19/24.
//
import Foundation
import SwiftUI

func openFullDiskAccessSettings() {
    // Attempt to open the Full Disk Access pane in System Settings
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
        NSWorkspace.shared.open(url)
    } else {
        // Fallback to general Security & Privacy pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}

func requestDirectoryAccess() -> Bool {
    let url = URL(fileURLWithPath: VoiceMemoDirectory)
    
    do {
        // Attempt to access the directory
        _ = try FileManager.default.contentsOfDirectory(atPath: VoiceMemoDirectory)
        return true
    } catch {
        openFullDiskAccessSettings()
        return false
//        // If access is denied, prompt the user to grant access
//        let openPanel = NSOpenPanel()
//        openPanel.message = "Please grant access to the Voice Memos directory"
//        openPanel.prompt = "Grant Access"
//        openPanel.directoryURL = url
//        openPanel.canChooseDirectories = true
//        openPanel.canChooseFiles = false
//        openPanel.allowsMultipleSelection = false
//        
//        var granted = false
//        openPanel.begin { response in
//            if response == .OK {
//                granted = true
//            } else {
//                let msg = "Access to Voice Memos directory is required"
//                showErrorAndQuit(message: msg)
//            }
//        }
//        return granted
    }
}

