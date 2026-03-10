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
var currentEpisode: Episode?
var lastAutoSavedSecond: Int = -1
var autosaveDisabledForCurrentEpisode: Bool = false
var VERSION = "0.1"

struct SavedEpisodeBookmark: Codable
{
    let feedTitle: String
    let episodeTitle: String
    let pubDate: String?
    let audioURL: String?
    let mp3Path: String
    var savedPosition: TimeInterval
    var savedAt: Date
}

private let savedEpisodesFileName = "saved_episodes.json"


printGreeting()
runREPL()

class PlayerDelegate: NSObject, AVAudioPlayerDelegate
{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    {
        avtimer?.invalidate()
        avtimer = nil
        currentEpisode = nil
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
        "l) list saved episodes",
        "x) exit"
    ]
}


private func handleCommand(_ line: String) async
{
    let input = line.trimmingCharacters(in: .newlines)
    if input.isEmpty
    {
        return
    }
    let parts = input.split(separator: " ")
    let cmd = parts[0];
    
    switch cmd
    {
        case "p":
            player?.pause()
            
        case "r":
            player?.play()
            
        case "e":
            await pickEpisode()

        case "l":
            await resumeSavedEpisode()
            
        case "s":
            await search()
        
        case "ff":
            fastforward()
            
        case "rr":
            rewind()
            
        case "j":
            if parts.count < 2
            {
                print("Usage: j <hh:mm:ss>")
            }
            else
            {
                jump(totime: String(parts[1]))
            }

        case "m":
            markCurrentEpisodeAsPlayed()
        
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
        "j) jump to time <hh:mm:ss>",
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

    do
    {
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
                    let title = item.collectionName
                    let author = item.artistName
                    let feed = item.feedUrl
                    print("\(idx + 1). \(title) — \(author)\n   Feed: \(feed)")
                }

                FileHandle.standardOutput.write(Data("Podcast number to subscribe to or x to exit> ".utf8))
                let line = readLine(strippingNewline: true) ?? ""
                if line.lowercased() == "x" { return }
                if let num = Int(line)
                {
                    CurrentFeedURL = decoded.results[num - 1].feedUrl
                    let searchresult  = decoded.results[num - 1]
                    await loadPodcast(feedstr: searchresult.feedUrl)
                  //  print("feed: \(String(describing: searchresult.collectionName))")
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
    catch
    {
        print("Request error: \(error.localizedDescription)")
    }
}


func savePodcast(podcast: PodcastFeed) throws
{
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(podcast)
    
    let podcastname = podcast.title
    let dirURL = URL(fileURLWithPath: "/\(Utils.getPodcastPath(podcast: podcast) ?? "err")", isDirectory: true)
    let fileURL = dirURL.appendingPathComponent("\(podcastname).json")
    try data.write(to: fileURL, options: Data.WritingOptions.atomic)
}


private func loadPodcast(feedstr:String) async
{
    let feed = await fetchFeed(from: feedstr)
    currentFeed = feed
}


private func pickEpisode() async
{
    var feedToUse: PodcastFeed?
    
    if let cf = currentFeed
    {
        feedToUse = cf
    }
    else if let testfeed = CurrentFeedURL
    {
        feedToUse = await fetchFeed(from: testfeed)
    }
    
    guard let feed = feedToUse else
    {
        print("No feed available. Use 't' to set a test feed or 's' to search first.")
        return
    }
    
    print("Episodes for \(feed.title)")
    
    for (idx, item) in feed.episodes.enumerated()
    {
        let pubDateText = Utils.formatPublishDate(item.pubDate)
        let durationText = Utils.formatDurationString(item.duration) ?? "--:--:--"
        print("\(idx + 1). \(item.title ?? "title") \(pubDateText) [\(durationText)]")
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
        do
        {
            if let mp3path = Utils.getMP3Path(episode:episode)
            {
                print("Downloading \(mp3path)...")
                try Utils.downloadMP3(from: audiourl, to: mp3path)
            }
            
        }
        catch
        {
            print("download error \(error)")
            return
        }
        
        do
        {
            currentEpisode = episode
            autosaveDisabledForCurrentEpisode = false
            try play(episode: episode, startAt: 0)
            episode.state = .Playing
            RunLoop.main.add(avtimer!, forMode: .default)
            await runPlaybackLoop()

        }
        catch
        {
            print("avaudioplayer error \(error)")
            return
        }
    }
}


private func stopPlayback()
{
    player?.stop()
    avtimer?.invalidate()
    avtimer = nil
    player = nil
    currentEpisode = nil
}


private func runPlaybackLoop() async
{
    while currentEpisode != nil
    {
        let cmd = showMenuAndReturnUserCommand(lines: playingMenu(), prompt: "> ")
        if cmd.lowercased() == "x"
        {
            stopPlayback()
            return
        }
        await handleCommand(cmd)
    }
}
    

private func play(episode:Episode) throws
{
    try play(episode: episode, startAt: 0)
}


private func play(episode:Episode, startAt: TimeInterval) throws
{
    if let mp3path = Utils.getMP3Path(episode: episode)
    {
        player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: mp3path))
        playerdelegate = PlayerDelegate()
        player?.delegate = playerdelegate
        player?.prepareToPlay()
        player?.currentTime = max(0, min(startAt, player?.duration ?? startAt))
        player?.play()
        startPlaybackTimer()
    }
}


private func startPlaybackTimer()
{
    lastAutoSavedSecond = -1
    avtimer = Timer.init(timeInterval: 1.0, repeats: true, block:
    { timer in
        guard let player = player else { return }
        let remaining = player.duration - player.currentTime
        let current = player.currentTime
        print("\u{001B}[A\rtime: \(Utils.formatTime(current)) - \(Utils.formatTime(remaining))\n>", terminator: "")
        fflush(stdout)

        let currentSecond = Int(current)
        if currentSecond > 0 && currentSecond % 5 == 0 && currentSecond != lastAutoSavedSecond
        {
            lastAutoSavedSecond = currentSecond
            saveCurrentPlaybackPosition(silent: true)
        }
    })
}


private func fastforward()
{
    let skipForwardSeconds: TimeInterval = 30
    
    if let player = player
    {
        let newTime = player.currentTime + skipForwardSeconds
        player.currentTime = min(newTime, player.duration)
    }
}


private func rewind()
{
    let rewindSeconds: TimeInterval = 15
    
    if let player = player
    {
        let newTime = player.currentTime - rewindSeconds
        player.currentTime = max(newTime, 0)
    }
}


private func jump(totime:String)
{
    if let player = player
    {
        let newtime = Utils.timeStringToSeconds(totime)
        player.currentTime = TimeInterval(newtime)
    }
}


private func savedEpisodesFilePath() -> String
{
    return "\(Utils.getPodDir())/\(savedEpisodesFileName)"
}


private func loadSavedBookmarks() -> [SavedEpisodeBookmark]
{
    let path = savedEpisodesFilePath()
    guard Utils.fileExists(at: path) else
    {
        return []
    }

    do
    {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode([SavedEpisodeBookmark].self, from: data)
    }
    catch
    {
        print("Failed to load saved episodes: \(error)")
        return []
    }
}


private func writeSavedBookmarks(_ bookmarks: [SavedEpisodeBookmark])
{
    do
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(bookmarks)
        try data.write(to: URL(fileURLWithPath: savedEpisodesFilePath()), options: .atomic)
    }
    catch
    {
        print("Failed to save episodes: \(error)")
    }
}


private func saveCurrentPlaybackPosition(silent: Bool = false)
{
    if autosaveDisabledForCurrentEpisode
    {
        return
    }

    guard let player = player, let episode = currentEpisode else
    {
        if !silent
        {
            print("Nothing is currently playing.")
        }
        return
    }

    guard let mp3Path = Utils.getMP3Path(episode: episode) else
    {
        if !silent
        {
            print("Could not determine episode file path.")
        }
        return
    }

    var bookmarks = loadSavedBookmarks()
    let newBookmark = SavedEpisodeBookmark(
        feedTitle: episode.parent?.name ?? "<unknown feed>",
        episodeTitle: episode.title ?? "<unknown episode>",
        pubDate: episode.pubDate,
        audioURL: episode.audioURL,
        mp3Path: mp3Path,
        savedPosition: player.currentTime,
        savedAt: Date()
    )

    if let existingIndex = bookmarks.firstIndex(where: { $0.mp3Path == mp3Path })
    {
        bookmarks[existingIndex] = newBookmark
    }
    else
    {
        bookmarks.append(newBookmark)
    }

    writeSavedBookmarks(bookmarks)
    if !silent
    {
        print("Saved \(newBookmark.episodeTitle) at \(Utils.formatTime(newBookmark.savedPosition)).")
    }
}


private func markCurrentEpisodeAsPlayed()
{
    guard let episode = currentEpisode else
    {
        print("Nothing is currently playing.")
        return
    }

    let currentMP3Path = Utils.getMP3Path(episode: episode)
    let bookmarks = loadSavedBookmarks()
    let matchesCurrentEpisode: (SavedEpisodeBookmark) -> Bool =
    {
        bookmark in
        if let currentMP3Path = currentMP3Path, bookmark.mp3Path == currentMP3Path
        {
            return true
        }

        if let audioURL = episode.audioURL, bookmark.audioURL == audioURL
        {
            return true
        }

        if bookmark.episodeTitle == (episode.title ?? "<unknown episode>") &&
            bookmark.feedTitle == (episode.parent?.name ?? "<unknown feed>")
        {
            return true
        }

        return false
    }
    let filtered = bookmarks.filter { !matchesCurrentEpisode($0) }
    let removedBookmarks = bookmarks.filter { matchesCurrentEpisode($0) }

    if filtered.count == bookmarks.count
    {
        print("No saved entry found for current episode.")
    }
    else
    {
        writeSavedBookmarks(filtered)
    }

    autosaveDisabledForCurrentEpisode = true
    stopPlayback()

    var candidatePaths = Set<String>()
    if let currentMP3Path = currentMP3Path
    {
        candidatePaths.insert(currentMP3Path)
    }
    for removed in removedBookmarks
    {
        candidatePaths.insert(removed.mp3Path)
    }

    var deletedCount = 0
    for path in candidatePaths
    {
        if Utils.fileExists(at: path)
        {
            do
            {
                try FileManager.default.removeItem(atPath: path)
                deletedCount += 1
            }
            catch
            {
                print("Failed to delete audio file at \(path): \(error)")
            }
        }
    }

    print("Marked as played, removed from saved episodes, and deleted \(deletedCount) downloaded file(s).")
}


private func resumeSavedEpisode() async
{
    let bookmarks = loadSavedBookmarks()
    if bookmarks.isEmpty
    {
        print("No saved episodes yet.")
        return
    }

    print("Saved episodes:")
    for (idx, bookmark) in bookmarks.enumerated()
    {
        print("\(idx + 1). \(bookmark.feedTitle) - \(bookmark.episodeTitle) [\(Utils.formatTime(bookmark.savedPosition))]")
    }

    FileHandle.standardOutput.write(Data("Saved episode number or x to exit> ".utf8))
    let line = readLine(strippingNewline: true) ?? ""
    if line.lowercased() == "x" { return }

    guard let selectedNum = Int(line), selectedNum > 0, selectedNum <= bookmarks.count else
    {
        print("Invalid selection.")
        return
    }

    let bookmark = bookmarks[selectedNum - 1]
    let filePath = bookmark.mp3Path

    if !Utils.fileExists(at: filePath), let audioURL = bookmark.audioURL
    {
        do
        {
            try Utils.downloadMP3(from: audioURL, to: filePath)
        }
        catch
        {
            print("Unable to restore audio file: \(error)")
            return
        }
    }

    if !Utils.fileExists(at: filePath)
    {
        print("Audio file not found and no downloadable URL available.")
        return
    }

    do
    {
        currentEpisode = Episode(
            parent: Podcast(name: bookmark.feedTitle, feedURL: "", currentEpisodeNum: 0),
            title: bookmark.episodeTitle,
            link: nil,
            pubDate: bookmark.pubDate,
            audioURL: bookmark.audioURL,
            duration: nil,
            currentPosition: nil,
            state: .Playing
        )
        autosaveDisabledForCurrentEpisode = false
        player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
        playerdelegate = PlayerDelegate()
        player?.delegate = playerdelegate
        player?.prepareToPlay()
        player?.currentTime = max(0, min(bookmark.savedPosition, player?.duration ?? bookmark.savedPosition))
        player?.play()
        startPlaybackTimer()

        RunLoop.main.add(avtimer!, forMode: .default)
        print("Resumed \(bookmark.episodeTitle) at \(Utils.formatTime(bookmark.savedPosition)).")
        await runPlaybackLoop()
    }
    catch
    {
        print("avaudioplayer error \(error)")
    }
}
