//
//  main.swift
//  PodBot
//
//  Created by Robert Dodson on 11/21/25.
//

import Foundation
import AVFoundation

var CurrentFeedURL : String?
var currentFeed: PodcastFeed?

var playerdelegate : PlayerDelegate?
var avtimer : Timer?

var player: AVAudioPlayer?
var VERSION = "0.1"


printGreeting()
runREPL()

class PlayerDelegate: NSObject, AVAudioPlayerDelegate
{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    {
        print("Playback finished. Success: \(flag)")
    }
}


private func runREPL()
{
   // DispatchQueue.global(qos: .userInitiated).async
    Task
    {
        while true
        {
            let cmd = showMenuAndReturnUserCommand(lines: topMenu(), prompt: "> ")
            await handleCommand(cmd)
        }
    }
    
    RunLoop.main.run()
}


private func showMenuAndReturnUserCommand(lines:[String],prompt:String) -> String
{
    for (_,line) in lines.enumerated()
    {
        print("\(line)")
    }
    
    print("\(prompt)",terminator: "")
    let cmd = readLine(strippingNewline: true) ?? ""
    
    return cmd;
}


private func topMenu() -> [String]
{
    return [
        "s) search for podcasts",
        "p) play episode \(currentFeed?.title ?? "")",
        "x) exit"
    ]
}


private func handleCommand(_ line: String) async
{
    let input = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if input.isEmpty
    {
        return
    }
    
    switch input
    {
        case "p":
            await pickEpisode()
            
        case "s":
            await search()
            
        case "x", "exit":
            print("Goodbye.")
            exit(0)
            
        default:
            print("Unknown command: \(input). Type ? for help.")
    }
}

private func printPrompt()
{
    FileHandle.standardOutput.write(Data("> ".utf8))
}


private func printGreeting()
{
    print("PodBot - version \(VERSION)")
}


private func readInput() -> String
{
    guard let line = readLine(strippingNewline: true) else
    {
        print("\nGoodbye.")
        exit(1)
    }
    
    return line
    
}

private func fetchFeed(from urlString: String) async -> PodcastFeed?
{
    guard let url = URL(string: urlString) else
    {
        print("Invalid feed URL: \(urlString)")
        return nil
    }
    
    var parsedFeed: PodcastFeed?
    
    do
    {
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode)
        {
            print("Feed HTTP error: status code \(http.statusCode)")
            return nil
        }
        
        guard !data.isEmpty else
        {
            print("Feed returned no data.")
            return nil
        }
        
        // Try XML first
        let parser = PodcastXMLParser()
        if let feed = parser.parse(data: data)
        {
            // Parsing succeeded; side-effects (like storing in currentFeed) handled elsewhere
            return feed
        }
        
        // If XML parsing failed, print raw for debugging
        if let raw = String(data: data, encoding: .utf8)
        {
            print("Failed to parse XML feed. Raw response (UTF-8):\n\(raw)")
        }
        else
        {
            print("Failed to parse XML feed and could not decode as UTF-8 text.")
        }
    }
    catch
    {
        print("Failed to fetch feed: \(error)")
    }
    
    return nil
}


private func search() async
{
    FileHandle.standardOutput.write(Data("Search> ".utf8))
    let line = readLine(strippingNewline: true) ?? ""
    let query = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else
    {
        print("Please enter a search term.")
        return
    }
    print("Searching for podcasts containing: \(query)")

    let searchterm = query.replacingOccurrences(of: " ", with: "+")
    let search_url = "https://itunes.apple.com/search?term=\(searchterm)&entity=podcast&limit=10"
    print("search_url: \(search_url)")

    guard let url = URL(string: search_url) else
    {
        print("Invalid URL.")
        return
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode)
        {
            print("HTTP error: status code \(http.statusCode)")
            return
        }
        
        guard !data.isEmpty else
        {
            print("No data returned.")
            return
        }
        
        do
        {
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            if decoded.results.isEmpty
            {
                print("No results found.")
            }
            else
            {
                print("\nTop \(decoded.results.count) results:")
                for (idx, item) in decoded.results.enumerated()
                {
                    let title = item.collectionName ?? "<No Title>"
                    let author = item.artistName ?? "<Unknown Author>"
                    let feed = item.feedUrl ?? "<No Feed URL>"
                    print("\(idx + 1). \(title) — \(author)\n   Feed: \(feed)")
                }

                FileHandle.standardOutput.write(Data("Podcast number to subscribe to or x to exit> ".utf8))
                let line = readLine(strippingNewline: true) ?? ""
                if line.lowercased() == "x" { return }
                if let num = Int(line)
                {
                    CurrentFeedURL = decoded.results[num - 1].feedUrl
                    do
                    {
                        let podcast = decoded.results[num - 1]
                        try savePodcast(podcast: podcast)
                        await loadPodcast(podcast: podcast)
                    }
                    catch
                    {
                        print("Error saving podcast to disk: \(error)")
                    }
                }
            }
        }
        catch
        {
            print("Failed to decode JSON: \(error). Raw response:")
            if let raw = String(data: data, encoding: .utf8)
            {
                print(raw)
            }
            else
            {
                print("<Non-UTF8 data>")
            }
        }
    }
    catch {
        print("Request error: \(error.localizedDescription)")
    }
}


func savePodcast(podcast: Podcast) throws
{
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(podcast)
    
    if let podcastname = podcast.collectionName
    {
        if let fileURL = URL(string:"file:///\(Utils.getPodDir())/\(podcastname).json")
        {
            try data.write(to: fileURL, options: .atomic)
        }
        else
        {
            print("Error bad fileURL")
        }
    }
    else
    {
        print("Error bad podcast name")
    }
}




private func loadPodcast(podcast:Podcast) async
{
    if let feedURL = podcast.feedUrl
    {
        let feed = await fetchFeed(from: feedURL)
        currentFeed = feed
        print("feed \(String(describing: feed?.title))")
    }
    else
    {
        print("No CurrentFeedURL set. Perform a search first and choose a result.")
    }
}


private func pickEpisode() async
{
    var feedToUse: PodcastFeed?
    if let cf = currentFeed {
        feedToUse = cf
    } else if let testfeed = CurrentFeedURL {
        feedToUse = await fetchFeed(from: testfeed)
    }
    guard let feed = feedToUse else {
        print("No feed available. Use 't' to set a test feed or 's' to search first.")
        return
    }
    
    for (idx, item) in feed.episodes.enumerated()
    {
        
        print("\(idx + 1). \(item.title ?? "title") \(item.pubDate ?? "date")")
        if (idx >= 10) { break; }
    }
    
    FileHandle.standardOutput.write(Data("Episode number or x to exit> ".utf8))
    let line = readLine(strippingNewline: true) ?? ""
    if line.lowercased() == "x" { return }
    var episodeNum = 0
    if let num = Int(line)
    {
        episodeNum = num - 1
    }
    
    if let audiourl = feed.episodes[episodeNum].audioURL
    {
        if let url = URL.init(string:audiourl)
        {
            do
            {
                print("Downloading...")
                try Utils.downloadMP3(from: url.absoluteString, to: "\(Utils.getPodDir())/\(url.lastPathComponent)")
                
            }
            catch
            {
                print("download error \(error)")
                return
            }
            
            do
            {
                let mp3 = URL(fileURLWithPath: "/\(Utils.getPodDir())/\(url.lastPathComponent)")
                player = try AVAudioPlayer(contentsOf: mp3)
                playerdelegate = PlayerDelegate()
                player?.delegate = playerdelegate
                player?.prepareToPlay()
                player?.play()
                
                avtimer = Timer.init(timeInterval: 1.0, repeats: true, block: { timer in
                    let remaining = player!.duration - player!.currentTime
                    print("\rtime left: \(Utils.formatTime(remaining))", terminator: "")
                    fflush(stdout)
                })
                
                RunLoop.main.add(avtimer!, forMode: .default)
                
               // RunLoop.main.run()
            }
            catch
            {
                print("avaudioplayer error \(error)")
                return
            }
        }
    }
}
    
    // Custom HTTP headers sometimes required for Podtrac or Libsyn
   // let headers = [
   //     "User-Agent": "PodBot",
 //       "Accept": "*/*"
 //   ]
    
    /*
    let asset = AVURLAsset(url: url, options: [
        "AVURLAssetHTTPHeaderFieldsKey": headers
    ])
    
    let item = AVPlayerItem(asset: asset)
    
    player = AVPlayer(playerItem: item)
    
    _ = item.observe(\.status, options: [.new, .initial])
    { item, _ in
        switch item.status
        {
            case .readyToPlay:
                print("READY — redirect chain OK")
            case .failed:
                print("FAILED:", item.error ?? "unknown error")
            case .unknown:
                print("UNKNOWN")
            @unknown default:
                print("???")
        }
    }
    

    print("Starting…")
        player?.play()
        RunLoop.main.run()
    
    */







