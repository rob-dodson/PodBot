//
//  PodcastXMLParser.swift
//  PodBot
//
//  Created by Robert Dodson on 11/22/25.
//
import Foundation

class PodcastXMLParser: NSObject, XMLParserDelegate
{
    private(set) var feedTitle: String?
    private(set) var feedDescription: String?
    private var items: [Episode] = []

    private var currentElement: String = ""
    private var currentItemTitle: String?
    private var currentItemLink: String?
    private var currentItemPubDate: String?
    private var currentItemAudioURL: String?
    private var accumulatingString: String = ""
    private var inItem: Bool = false

    func parse(data: Data) -> PodcastFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        // RSS feeds can be in various encodings; XMLParser handles that via header.
        if parser.parse() {
            return PodcastFeed(title: feedTitle, description: feedDescription, episodes: items)
        } else {
            return nil
        }
    }

    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        accumulatingString = ""
        if currentElement == "item" || currentElement == "entry" { // RSS item or Atom entry
            inItem = true
            currentItemTitle = nil
            currentItemLink = nil
            currentItemPubDate = nil
            currentItemAudioURL = nil
        }
        if inItem && currentElement == "link", let href = attributeDict["href"], !href.isEmpty {
            // Atom uses <link href="..."/>
            currentItemLink = href
        }
        if inItem && currentElement == "enclosure", let url = attributeDict["url"], !url.isEmpty {
            currentItemAudioURL = url
        }
        if inItem && currentElement == "link" {
            if let rel = attributeDict["rel"], rel.lowercased() == "enclosure", let href = attributeDict["href"], !href.isEmpty {
                currentItemAudioURL = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        accumulatingString += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = accumulatingString.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = elementName.lowercased()
        if inItem {
            switch name {
            case "title":
                if !value.isEmpty { currentItemTitle = (currentItemTitle ?? "") + value }
            case "link":
                if !value.isEmpty { currentItemLink = (currentItemLink ?? "") + value }
            case "pubdate", "updated", "published":
                if !value.isEmpty { currentItemPubDate = (currentItemPubDate ?? "") + value }
            case "item", "entry":
                let item = Episode(title: currentItemTitle, link: currentItemLink, pubDate: currentItemPubDate, audioURL: currentItemAudioURL)
                items.append(item)
                inItem = false
            default:
                break
            }
        } else {
            switch name {
            case "title":
                if !value.isEmpty { feedTitle = (feedTitle ?? "") + value }
            case "description", "subtitle", "tagline":
                if !value.isEmpty { feedDescription = (feedDescription ?? "") + value }
            default:
                break
            }
        }
        accumulatingString = ""
        currentElement = ""
    }
}
