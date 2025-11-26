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
        "e) pick episode to play: \(currentFeed?.title ?? "")",
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
            player?.pause()
            
        case "r":
            player?.play()
            
        case "e":
            await pickEpisode()
            
        case "s":
            await search()
        
        case "ff":
            fastforward()
            
        case "rr":
            rewind()
        
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
            return feed
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


private func searchMenu() -> [String]
{
    return [
         "x) exit"
    ]
}

private func playingMenu() -> [String]
{
    return [
        "p) pause",
        "r) resume",
        "ff) fastforward 30",
        "rr) rewind 15",
        "m) mark as played",
        "x) exit"
    ]
}

private func search() async
{
    var query : String?
    
    while true
    {
        let cmd = showMenuAndReturnUserCommand(lines: searchMenu(), prompt: "search> ")
        if cmd.lowercased() == "x" { return }
        
        query = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query!.isEmpty else
        {
            print("Please enter a search term.")
            continue
        }
        break;
    }
    
    
    print("Searching for podcasts containing: \(query ?? "error")")

    let searchterm = query?.replacingOccurrences(of: " ", with: "+")
    let search_url = "https://itunes.apple.com/search?term=\(searchterm ?? "term")&entity=podcast&limit=10"
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
        let dirURL = URL(fileURLWithPath: "/\(Utils.getPodDir())", isDirectory: true)
        let fileURL = dirURL.appendingPathComponent("\(podcastname).json")
        try data.write(to: fileURL, options: .atomic)
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
    
    var episode = feed.episodes[episodeNum]
    if let audiourl = episode.audioURL
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
                try play(episode: episode)
                episode.state = .Playing
                Task{
                    while true
                    {
                        let cmd = showMenuAndReturnUserCommand(lines: playingMenu(), prompt: "> ")
                        if cmd.lowercased() == "x" { return }
                        await handleCommand(cmd)
                    }
                }
                RunLoop.main.add(avtimer!, forMode: .default)

            }
            catch
            {
                print("avaudioplayer error \(error)")
                return
            }
        }
    }
}
    

private func play(episode:Episode) throws
{
    if let audiourl = episode.audioURL
    {
        let fileName = URL(string: audiourl)?.lastPathComponent ?? audiourl
        let dirURL = URL(fileURLWithPath: "/\(Utils.getPodDir())", isDirectory: true)
        let mp3 = dirURL.appendingPathComponent(fileName)
        
        player = try AVAudioPlayer(contentsOf: mp3)
        playerdelegate = PlayerDelegate()
        player?.delegate = playerdelegate
        player?.prepareToPlay()
        player?.play()
        
        avtimer = Timer.init(timeInterval: 1.0, repeats: true, block:
        { timer in
            guard let player = player else { return }
            let remaining = player.duration - player.currentTime
            print("\u{001B}[A\rtime left: \(Utils.formatTime(remaining))\n>", terminator: "")
            fflush(stdout)
        })
    }
}

private func fastforward()
{
    let skipForwardSeconds: TimeInterval = 30
    
    if let player = player {
        let newTime = player.currentTime + skipForwardSeconds
        player.currentTime = min(newTime, player.duration) // clamp to end
    }
}


private func rewind()
{
    let rewindSeconds: TimeInterval = 15
    
    if let player = player {
        let newTime = player.currentTime - rewindSeconds
        player.currentTime = max(newTime, 0) // clamp to beginning
    }
}
