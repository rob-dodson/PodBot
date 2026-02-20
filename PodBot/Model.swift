//
//  Model.swift
//  PodBot
//
//  Created by Robert Dodson on 11/23/25.
//
import Foundation


struct ITunesSearchResponse: Decodable
{
    let resultCount: Int
    let results: [RSSSearchResult]
}

struct RSSSearchResult: Codable
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

struct PodcastRSSFeed: Codable
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

typealias PodcastFeed = PodcastRSSFeed

enum EpisodeState: String, Codable
{
    case Played
    case NotPlayed
    case Playing
    case Paused
}

struct Podcast : Codable
{
    let name: String
    let feedURL: String
    let currentEpisodeNum: Int
}

struct Episode: Codable
{
    var parent: Podcast?
    let title: String?
    let link: String?
    let pubDate: String?
    let audioURL: String?
    let currentPosition: Int?
    var state: EpisodeState
}


