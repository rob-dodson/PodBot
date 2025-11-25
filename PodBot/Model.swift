//
//  Model.swift
//  PodBot
//
//  Created by Robert Dodson on 11/23/25.
//
import Foundation

struct Podcast: Decodable,Encodable
{
    let collectionName: String?
    let artistName: String?
    let feedUrl: String?
}

struct ITunesSearchResponse: Decodable
{
    let resultCount: Int
    let results: [Podcast]
}

struct Episode: Decodable
{
    let title: String?
    let link: String?
    let pubDate: String?
    let audioURL: String?
}

struct PodcastFeed: Decodable
{
    let title: String?
    let description: String?
    let episodes: [Episode]
}
