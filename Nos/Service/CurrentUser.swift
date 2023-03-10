//
//  CurrentUser.swift
//  Nos
//
//  Created by Christopher Jorgensen on 2/21/23.
//

import Foundation
import CoreData

enum CurrentUser {
    static var privateKey: String? {
        if let privateKeyData = KeyChain.load(key: KeyChain.keychainPrivateKey) {
            let hexString = String(decoding: privateKeyData, as: UTF8.self)
            return hexString
        }
        
        return nil
    }
    
    static var publicKey: String? {
        if let privateKey = privateKey {
            if let keyPair = KeyPair.init(privateKeyHex: privateKey) {
                return keyPair.publicKey.hex
            }
        }
        return nil
    }
    
    static var context: NSManagedObjectContext?
    
    static var subscriptions: [String] = []
    
    static var relayService: RelayService? {
        didSet {
            subscribe()
        }
    }
    
    static var author: Author? {
        if let publicKey, let context {
            return try? Author.findOrCreate(by: publicKey, context: context)
        }
        return nil
    }
    
    static var follows: Set<Follow>? {
        let followSet = author?.follows as? Set<Follow>
        let umutedSet = followSet?.filter({
            if let author = $0.destination {
                return author.muted == false
            }
            return false
        })
        return umutedSet
    }
    
    static func subscribe() {
        // Always listen to my changes
        if let key = publicKey {
            // Close out stale requests
            if !subscriptions.isEmpty {
                relayService?.sendCloseToAll(subscriptions: subscriptions)
                subscriptions.removeAll()
            }

            let textFilter = Filter(authorKeys: [key], kinds: [.text], limit: 100)
            if let textSub = relayService?.requestEventsFromAll(filter: textFilter) {
                subscriptions.append(textSub)
            }

            let metaFilter = Filter(authorKeys: [key], kinds: [.metaData, .contactList], limit: 100)
            if let metaSub = relayService?.requestEventsFromAll(filter: metaFilter) {
                subscriptions.append(metaSub)
            }
        }
    }
    
    static func isFollowing(author profile: Author) -> Bool {
        guard let following = author?.follows as? Set<Follow>, let key = profile.hexadecimalPublicKey else {
            return false
        }
        
        let followKeys = following.keys
        return followKeys.contains(key)
    }
    
    static func publishMetaData() {
        guard context != nil else {
            print("Error: Can't publish without context")
            return
        }
    }
    
    static func publishContactList(tags: [[String]]) {
        guard context != nil else {
            print("Error: Can't publish without context")
            return
        }
        
        guard let relays = author?.relays?.allObjects as? [Relay],
            let pubKey = publicKey else {
            print("Error: No relay service")
            return
        }

        var relayString = "{"
        for relay in relays {
            if let address = relay.address {
                relayString += "\"\(address)\":{\"write\":true,\"read\":true},"
            }
        }
        relayString.removeLast()
        relayString += "}"
        
        let time = Int64(Date.now.timeIntervalSince1970)
        let kind = EventKind.contactList.rawValue
        var jsonEvent = JSONEvent(pubKey: pubKey, createdAt: time, kind: kind, tags: tags, content: relayString)
        
        if let privateKey = privateKey, let pair = KeyPair(privateKeyHex: privateKey) {
            do {
                try jsonEvent.sign(withKey: pair)
                let event = try EventProcessor.parse(jsonEvent: jsonEvent, in: context!)
                relayService?.publishToAll(event: event)
            } catch {
                print("failed to update Follows \(error.localizedDescription)")
            }
        }
    }
    
    /// Follow by public hex key
    static func follow(author toFollow: Author) {
        guard context != nil else {
            print("Error: Can't publish without context")
            return
        }

        guard let followKey = toFollow.hexadecimalPublicKey else {
            print("Error: followKey is nil")
            return
        }

        print("Following \(followKey)")

        var followKeys = follows?.keys ?? []
        followKeys.append(followKey)
        
        // Update author to add the new follow
        if let followedAuthor = try? Author.find(by: followKey, context: context!), let currentUser = author {
            // Add to the current user's follows
            let follow = try! Follow.findOrCreate(source: currentUser, destination: followedAuthor, context: context!)
            if let currentFollows = currentUser.follows?.mutableCopy() as? NSMutableSet {
                currentFollows.add(follow)
                currentUser.follows = currentFollows
            }

            // Add from the current user to the author's followers
            if let followedAuthorFollowers = followedAuthor.followers?.mutableCopy() as? NSMutableSet {
                followedAuthorFollowers.add(follow)
                followedAuthor.followers = followedAuthorFollowers
            }
        }
        
        publishContactList(tags: followKeys.tags)
    }
    
    /// Unfollow by public hex key
    static func unfollow(author toUnfollow: Author) {
        guard context != nil else {
            print("Error: Can't publish without context")
            return
        }
        
        guard let unfollowedKey = toUnfollow.hexadecimalPublicKey else {
            print("Error: unfollowedKey is nil")
            return
        }

        print("Unfollowing \(unfollowedKey)")
        
        let stillFollowingKeys = (follows ?? [])
            .keys
            .filter { $0 != unfollowedKey }
        
        // Update author to only follow those still following
        if let unfollowedAuthor = try? Author.find(by: unfollowedKey, context: context!), let currentUser = author {
            // Remove from the current user's follows
            let unfollows = Follow.follows(source: currentUser, destination: unfollowedAuthor, context: context!)
            if let currentFollows = currentUser.follows?.mutableCopy() as? NSMutableSet {
                currentFollows.remove(unfollows)
                currentUser.follows = currentFollows
            }
            
            // Remove from the unfollowed author's followers
            if let unfollowedAuthorFollowers = unfollowedAuthor.followers?.mutableCopy() as? NSMutableSet {
                unfollowedAuthorFollowers.remove(unfollows)
                unfollowedAuthor.followers = unfollowedAuthorFollowers
            }
        }

        publishContactList(tags: stillFollowingKeys.tags)

        // Delete cached texts from this person
        if let author = try? Author.find(by: unfollowedKey, context: context!) {
            author.deleteAllPosts(context: context!)
        }
    }
}
