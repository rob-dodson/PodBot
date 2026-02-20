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
        
        do
        {
            try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
            print("Created directory at: \(newDir.path)")
        }
        catch
        {
            print("Error creating directory:", error)
        }
        
        return newDir.path
    }
    
    
    static func getPodcastPath(podcast: PodcastFeed) -> String?
    {
        let subdir = podcast.title.replacingOccurrences(of: " ", with: "_")
        
        let dir = "\(getPodDir())/\(subdir)"
        
        if (!fileExists(at: dir))
        {
            if let dirurl = URL(string:"file:///\(dir)")
            {
                do
                {
                    try FileManager.default.createDirectory(at: dirurl, withIntermediateDirectories: true)
                }
                catch
                {
                    print("failed to make subdir: \(dirurl.path) \(error)")
                }
            }
        }
        
        return dir
    }
    
    
    static func getMP3Path(episode: Episode) -> String?
    {
        if (episode.parent == nil)
        {
            return nil
        }
        else
        {
            let podcastName = episode.parent!.name.replacingOccurrences(of: " ", with: "_")
            let subdir = "\(getPodDir())/\(podcastName)"
            if (!fileExists(at: subdir))
            {
                do
                {
                    try FileManager.default.createDirectory(at: URL(fileURLWithPath: subdir), withIntermediateDirectories: true)
                }
                catch
                {
                    print("failed to make subdir: \(subdir) \(error)")
                }
            }

            let mp3url = URL(string:episode.audioURL ?? "title")
            
            return "\(subdir)/\(mp3url?.lastPathComponent ?? "media.mp3")"
        }
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
    
    static func timeStringToSeconds(_ time: String) -> Int
    {
        let parts = time.split(separator: ":").map { Int($0) ?? 0 }
        
        // Support "HH:MM:SS", "MM:SS", or "SS"
        switch parts.count
        {
            case 3:
                return parts[0] * 3600 + parts[1] * 60 + parts[2]
            case 2:
                return parts[0] * 60 + parts[1]
            case 1:
                return parts[0]
            default:
                return 0
        }
    }
}
