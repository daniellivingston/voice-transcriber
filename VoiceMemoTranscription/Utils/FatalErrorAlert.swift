//
//  FatalErrorAlert.swift
//  Josh Smells Like Used Socks
//
//  Created by Daniel Livingston on 9/19/24.
//
import SwiftUI

// Function to display the error alert and terminate the app
func showErrorAndQuit(message: String) {
    let alert = NSAlert()
    alert.messageText = "Fatal Error"
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Quit")
    
    // Ensure UI updates happen on the main thread
    DispatchQueue.main.async {
        // Run the alert modally
        alert.runModal()
        // Terminate the app after the alert is dismissed
        NSApplication.shared.terminate(nil)
    }
}

