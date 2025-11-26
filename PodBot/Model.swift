//
//  Model.swift
//  PodBot
//
//  Created by Robert Dodson on 11/23/25.
//
import Foundation

struct Podcast: Codable
{
    let collectionName: String?
    let artistName: String?
    let feedUrl: String?
    let currentEpsiode: Episode?
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
    let title: String?
    let link: String?
    let pubDate: String?
    let audioURL: String?
    let currentPosition: Int?
    var state: EpisodeState
}

struct PodcastFeed: Decodable
{
    let title: String?
    let description: String?
    let episodes: [Episode]
}
