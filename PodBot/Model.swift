//
//  Model.swift
//  PodBot
//
//  Created by Robert Dodson on 11/23/25.
//
import Foundation

struct Podcast: Codable
{
    let collectionName: String
    let artistName: String
    let feedUrl: String

    init(collectionName: String = "<no name>", artistName: String = "<no artist>", feedUrl: String = "<no url>")
    {
        self.collectionName = collectionName
        self.artistName = artistName
        self.feedUrl = feedUrl
    }
}

struct ITunesSearchResponse: Decodable
{
    let resultCount: Int
    let results: [Podcast]
}

enum EpisodeState: String, Codable {
    case Played
    case NotPlayed
    case Playing
    case Paused
}

struct Episode: Codable
{
    var parent: PodcastFeed?
    let title: String?
    let link: String?
    let pubDate: String?
    let audioURL: String?
    let currentPosition: Int?
    var state: EpisodeState
}

struct PodcastFeed: Codable
{
    let title: String
    let description: String
    var episodes: [Episode]
    
    init(title: String = "<no title>", description: String = "<no description>", episodes: [Episode] = [])
    {
        self.title = title
        self.description = description
        self.episodes = episodes
    }
}
