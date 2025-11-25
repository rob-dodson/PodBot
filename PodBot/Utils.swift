//
//  Utils.swift
//  PodBot
//
//  Created by Robert Dodson on 11/23/25.
//
import Foundation


class Utils
{

    static func fileExists(at path: String) -> Bool
    {
        return FileManager.default.fileExists(atPath: path)
    }

    
    static func formatTime(_ seconds: TimeInterval) -> String
    {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    
    static func getPodDir() -> String
    {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let newDir = home.appendingPathComponent(".podbot")
        if fileExists(at: newDir.path)
        {
            return newDir.path
        }
        
        do {
            try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
            print("Created directory at: \(newDir.path)")
        } catch {
            print("Error creating directory:", error)
        }
        
        return newDir.path
    }
    
    
    static func downloadMP3(from urlString: String, to destinationPath: String) throws
    {
        // If the file already exists, skip downloading
        if fileExists(at: destinationPath)
        {
            print("File already exists at: \(destinationPath)")
            return
        }

        guard let url = URL(string: urlString) else
        {
            throw NSError(domain: "InvalidURL", code: -1)
        }
        
        
        let data = try Data(contentsOf: url)   // Blocks until download finished
        let destURL = URL(fileURLWithPath: destinationPath)
        try data.write(to: destURL)
        
        print("Downloaded to \(destURL.path)")
    }
    
    
    static func downloadMP3Async(from urlString: String, to destinationPath: String)
    {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        let destURL = URL(fileURLWithPath: destinationPath)
        
        // If the file already exists, skip downloading
        if fileExists(at: destinationPath) {
            print("File already exists at: \(destinationPath)")
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                print("Download error:", error)
                return
            }
            
            guard let tempURL = tempURL else {
                print("No temp file")
                return
            }
            
            do {
                // Remove existing file if needed
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                print("Downloaded to \(destURL.path)")
            } catch {
                print("File error:", error)
            }
        }
        
        task.resume()
    }
}

