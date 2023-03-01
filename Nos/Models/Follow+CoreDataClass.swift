//
//  Follow+CoreDataClass.swift
//  Nos
//
//  Created by Christopher Jorgensen on 2/15/23.
//

import Foundation
import CoreData

typealias Followed = [Follow]

@objc(Follow)
public class Follow: NosManagedObject {
    
    class func upsert(
        by author: Author,
        jsonTag: [String],
        context: NSManagedObjectContext
    ) throws -> Follow {
        var follow: Follow
        let fetchRequest = NSFetchRequest<Follow>(entityName: "Follow")
        fetchRequest.predicate = NSPredicate(
            format: "source.hexadecimalPublicKey = %@ AND destination.hexadecimalPublicKey = %@",
            author.hexadecimalPublicKey!,
            jsonTag[1]
        )
        fetchRequest.fetchLimit = 1
        if let existingFollow = try context.fetch(fetchRequest).first {
            follow = existingFollow
            // TODO: abort if the event we are processing is older than the one we have in Core Data
        } else {
            follow = Follow(context: context)
        }
        
        follow.source = author
        
        let followedKey = jsonTag[1]
        let followedAuthor = try Author.findOrCreate(by: followedKey, context: context)
        follow.destination = followedAuthor
        
        if jsonTag.count > 2 {
            follow.relay = Relay.findOrCreate(by: jsonTag[2], context: context)
        }
        
        if jsonTag.count > 3 {
            follow.petName = jsonTag[3]
        }
        
        return follow
    }
    
    @nonobjc public class func follows(from authors: [Author]) -> NSFetchRequest<Follow> {
        let fetchRequest = NSFetchRequest<Follow>(entityName: "Follow")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Follow.petName, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "source IN %@", authors)
        return fetchRequest
    }
    
    @nonobjc public class func emptyRequest() -> NSFetchRequest<Follow> {
        let fetchRequest = NSFetchRequest<Follow>(entityName: "Follow")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Follow.petName, ascending: true)]
        fetchRequest.fetchLimit = 0
        return fetchRequest
    }
    
    @nonobjc public class func deleteFollowsRequest(in follows: Set<Follow>) -> NSBatchDeleteRequest {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Follow")
        fetchRequest.predicate = NSPredicate(format: "SELF IN %@", follows)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        return deleteRequest
    }
    
    class func deleteFollows(in follows: Set<Follow>, context: NSManagedObjectContext) {
        let deleteRequest = Follow.deleteFollowsRequest(in: follows)
        
        do {
            try context.execute(deleteRequest)
        } catch let error as NSError {
            print("Failed to delete follows. Error: \(error.description)")
        }
    }
}
