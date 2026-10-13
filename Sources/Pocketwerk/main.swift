import Foundation
import PocketwerkKit

// `Pocketwerk --cli <command>` runs the command line interface and never starts the GUI.
if let i = CommandLine.arguments.firstIndex(of: "--cli") {
    exit(PocketwerkCLI.run(Array(CommandLine.arguments[(i + 1)...])))
}

PocketwerkMain.run()
