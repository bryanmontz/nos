//
//  PreviewData.swift
//  Nos
//
//  Created by Matthew Lorentz on 5/9/23.
//

import SwiftUI
import Foundation
import Dependencies
import CoreData

struct InjectPreviewData: ViewModifier {
    
    var previewData: PreviewData
    
    func body(content: Content) -> some View {
        content
            .environmentObject(previewData.router)
            .environment(\.managedObjectContext, previewData.persistenceController.viewContext)
    }
}

extension View {
    func inject(previewData: PreviewData) -> some View {
        self.modifier(InjectPreviewData(previewData: previewData))
    }
}

// swiftlint:disable line_length

/// Some test data that can be used in SwiftUI Previews
struct PreviewData {
    
    // MARK: - Environment
    @Dependency(\.persistenceController) var persistenceController 
    @Dependency(\.router) var router
    @Dependency(\.relayService) var relayService
    lazy var previewContext: NSManagedObjectContext = {
        persistenceController.container.viewContext  
    }()
//    static var emptyPersistenceController = PersistenceController.empty
//    static var emptyPreviewContext = emptyPersistenceController.container.viewContext
//    static var emptyRelayService = RelayService()
//    static var relayService = RelayService()
    
    // MARK: - User

    @MainActor lazy var currentUser: CurrentUser = {
        let currentUser = CurrentUser()
        currentUser.viewContext = previewContext
        currentUser.relayService = relayService
        Task { await currentUser.setKeyPair(KeyFixture.keyPair) }
        return currentUser
    }()

    // MARK: - Authors
    
    lazy var previewAuthor: Author = {
        alice
    }()
    
    lazy var alice: Author = {
        let author = Author(context: previewContext)
        author.hexadecimalPublicKey = KeyFixture.alice.publicKeyHex
        author.name = "Alice"
        author.nip05 = "alice@nos.social"
        author.profilePhotoURL = URL(string: "https://github.com/planetary-social/nos/assets/1165004/07f83f00-4555-4db3-85fc-f1a05b1908a2")
        author.about = """
        Bitcoin Maximalist extraordinaire! 🚀 HODLing since the days of Satoshi's personal phone number. Always clad in my 'Bitcoin or Bust' t-shirt, preaching the gospel of the Orange Coin. 🍊 Lover of decentralized currencies, disruptive technology, and long walks on the blockchain. 💪 When I'm not evangelizing BTC, you'll find me stacking sats, perfecting my lambo moonwalk, and dreaming of a world ruled by blockchain memes. 💸 Join me on this rollercoaster ride to financial freedom, where we laugh at the mere mortals still stuck with fiat. #BitcoinFTW #WhenLambo 🚀
        """
        return author
    }()
    
    lazy var bob: Author = {
        let author = Author(context: previewContext)
        author.hexadecimalPublicKey = KeyFixture.bob.publicKeyHex
        author.name = "Bob"
        author.profilePhotoURL = URL(string: "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Ftse1.mm.bing.net%2Fth%3Fid%3DOIP.r1ZOH5E3M6WiK6aw5GRdlAHaEK%26pid%3DApi&f=1&ipt=42ae9de7730da3bda152c5980cd64b14ccef37d8f55b8791e41b4667fc38ddf1&ipo=images")
        
        return author
    }()
    
    lazy var eve: Author = {
        let author = Author(context: previewContext)
        author.hexadecimalPublicKey = KeyFixture.eve.publicKeyHex
        author.name = "Eve"
        
        return author
    }()
    
    // MARK: - Notes
    
    lazy var shortNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "1"
        note.kind = EventKind.text.rawValue
        note.content = "Hello, world!"
        note.author = previewAuthor
        note.createdAt = .now
        try! previewContext.save()
        return note
    }()
    
    lazy var imageNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "2"
        note.kind = EventKind.text.rawValue
        note.content = "Hello, world!https://cdn.ymaws.com/nacfm.com/resource/resmgr/images/blog_photos/footprints.jpg"
        note.author = previewAuthor
        note.createdAt = .now
        try! previewContext.save()
        return note
    }()
    
    lazy var doubleImageNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "2"
        note.kind = EventKind.text.rawValue
        note.content = """
        Hello, world!
        https://cdn.ymaws.com/nacfm.com/resource/resmgr/images/blog_photos/footprints.jpg"
        https://nostr.build/i/nostr.build_1b958a2af7a2c3fcb2758dd5743912e697ba34d3a6199bfb1300fa6be1dc62ee.jpeg
        """
        note.author = previewAuthor
        note.createdAt = .now
        try! previewContext.save()
        return note
    }()
    
    lazy var verticalImageNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "3"
        note.kind = EventKind.text.rawValue
        note.content = "Hello, world!https://nostr.build/i/nostr.build_1b958a2af7a2c3fcb2758dd5743912e697ba34d3a6199bfb1300fa6be1dc62ee.jpeg"
        note.author = previewAuthor
        note.createdAt = .now
        try! previewContext.save()
        return note
    }()
    
    lazy var veryWideImageNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "4"
        note.kind = EventKind.text.rawValue
        note.content = "Hello, world! https://nostr.build/i/nostr.build_db8287dde9aedbc65df59972386fde14edf9e1afc210e80c764706e61cd1cdfa.png"
        note.author = previewAuthor
        note.createdAt = .now
        try! previewContext.save()
        return note
    }()
    
    lazy var longNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "5"
        note.kind = EventKind.text.rawValue
        note.createdAt = .now
        note.content = .loremIpsum(5)
        note.author = previewAuthor
        try! previewContext.save()
        return note
    }()
    
    lazy var longFormNote: Event = {
        let note = Event(context: previewContext)
        note.identifier = "6"
        note.createdAt = .now
        note.kind = EventKind.longFormContent.rawValue
        note.content = 
        """
        # This note
        
        is **formatted** with
        > _markdown_
        
        And it has a link to [nos.social](https://nos.social).
        """
        note.author = previewAuthor
        try! previewContext.save()
        return note
    }()
    
    lazy var repost: Event = {
        let originalPostAuthor = Author(context: previewContext)
        originalPostAuthor.hexadecimalPublicKey = KeyFixture.bob.publicKeyHex
        originalPostAuthor.name = "Bob"
        originalPostAuthor.profilePhotoURL = URL(string: "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Ftse1.mm.bing.net%2Fth%3Fid%3DOIP.r1ZOH5E3M6WiK6aw5GRdlAHaEK%26pid%3DApi&f=1&ipt=42ae9de7730da3bda152c5980cd64b14ccef37d8f55b8791e41b4667fc38ddf1&ipo=images")

        let repostedNote = Event(context: previewContext)
        repostedNote.identifier = "3"
        repostedNote.kind = EventKind.text.rawValue
        repostedNote.createdAt = .now
        repostedNote.content = "Please repost this Alice"
        repostedNote.author = originalPostAuthor
        
        let reference = try! EventReference(jsonTag: ["e", "3", ""], context: previewContext)

        let repost = Event(context: previewContext)
        repost.identifier = "4"
        repost.kind = EventKind.repost.rawValue
        repost.createdAt = .now
        repost.author = previewAuthor
        repost.eventReferences = NSOrderedSet(array: [reference])
        try! previewContext.save()
        return repost
    }()
}

// swiftlint:enable line_length
