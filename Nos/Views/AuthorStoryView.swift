//
//  AuthorStoryView.swift
//  Nos
//
//  Created by Matthew Lorentz on 3/23/23.
//

import Dependencies
import SwiftUI
import CoreData

struct AuthorStoryView: View {
    
    var author: Author
    var showNextAuthor: () -> Void
    var showPreviousAuthor: () -> Void
    
    @FetchRequest private var notes: FetchedResults<Event>

    @State private var selectedNote: Event?

    @Binding private var cutoffDate: Date

    @State private var subscriptionIDs = [String]()

    @EnvironmentObject private var router: Router
    @EnvironmentObject private var relayService: RelayService

    @Environment(\.managedObjectContext) private var viewContext
    @Dependency(\.persistenceController) private var persistenceController
    
    init(author: Author, cutoffDate: Binding<Date>, showPreviousAuthor: @escaping () -> Void, showNextAuthor: @escaping () -> Void) {
        self.author = author
        self._cutoffDate = cutoffDate
        self.showPreviousAuthor = showPreviousAuthor
        self.showNextAuthor = showNextAuthor
        _notes = FetchRequest(fetchRequest: author.storiesRequest(since: cutoffDate.wrappedValue))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if let selectedNote {
                        Button {
                            router.push(selectedNote)
                        } label: {
                            StoryNoteView(note: selectedNote, minHeight: geometry.size.height)
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .id(selectedNote)
        .overlay(alignment: .leading) {
            Button {
                guard let selectedNote, let selectedNoteIndex = notes.firstIndex(of: selectedNote) else {
                    return
                }
                if selectedNoteIndex > 0 {
                    let previousIndex = notes.index(before: selectedNoteIndex)
                    self.selectedNote = notes[safe: previousIndex]
                } else {
                    showPreviousAuthor()
                }
            } label: {
                Color.red.opacity(0)
            }
            .frame(maxWidth: 100, maxHeight: .infinity)
        }
        .overlay(alignment: .trailing) {
            Button {
                guard let selectedNote, let selectedNoteIndex = notes.firstIndex(of: selectedNote) else {
                    return
                }
                if selectedNoteIndex < notes.count - 1 {
                    let nextIndex = notes.index(after: selectedNoteIndex)
                    self.selectedNote = notes[safe: nextIndex]
                } else {
                    showNextAuthor()
                }
            } label: {
                Color.green.opacity(0)
            }
            .frame(maxWidth: 100, maxHeight: .infinity)
        }
        .overlay(alignment: .topLeading) {
            VStack {
                HStack(spacing: 6) {
                    ForEach(notes) { note in
                        Button {
                            selectedNote = note
                        } label: {
                            RoundedRectangle(cornerRadius: 21)
                                .frame(maxWidth: .infinity, maxHeight: 3)
                                .cornerRadius(7)
                                .foregroundColor(note.isEqual(selectedNote) == true ? .accent : .secondaryText)
                                .padding(.bottom, 5)
                                .padding(.top, 15)
                        }
                    }
                }
                .padding(.horizontal, 10)

                Button {
                    router.push(author)
                } label: {
                    HStack(alignment: .center) {
                        AuthorLabel(author: author)
                            .padding(0)
                        if let elapsedTime = selectedNote?.createdAt?.elapsedTimeFromNowString() {
                            Text(elapsedTime)
                                .lineLimit(1)
                                .font(.body)
                                .foregroundColor(.secondaryText)
                        }
                        Spacer()
                        if let selectedNote {
                            NoteOptionsButton(note: selectedNote)
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 0)
                }
            }
            .padding(.bottom, 10)
            .background {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .storiesBgTop.opacity(1), location: 0.25),
                        Gradient.Stop(color: .storiesBgTop.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let selectedNote {
                BottomOverlay(note: selectedNote)
            } else {
                EmptyView()
            }
        }
        .task {
            if selectedNote == nil {
                if let firstNote = notes.first {
                    selectedNote = firstNote
                } else {
                    showNextAuthor()
                }
            }
        }
        .task {
            await subscribeToReplies()
        }
    }

    func subscribeToReplies() async {
        // Close out stale requests
        if !subscriptionIDs.isEmpty {
            await relayService.decrementSubscriptionCount(for: subscriptionIDs)
            subscriptionIDs.removeAll()
        }

        let eTags = notes.compactMap { $0.identifier }
        let filter = Filter(kinds: [.text, .like, .delete, .repost], eTags: eTags)
        let subID = await relayService.openSubscription(with: filter)
        subscriptionIDs.append(subID)
    }
}

fileprivate struct BottomOverlay: View {
    
    var note: Event

    @Dependency(\.persistenceController) private var persistenceController
    @Environment(\.managedObjectContext) private var viewContext

    @EnvironmentObject private var router: Router

    @State private var replyCount = 0
    @State private var replyAvatarURLs = [URL]()

    var body: some View {
        HStack(spacing: 0) {
            StackedAvatarsView(avatarUrls: replyAvatarURLs, size: 20, border: 0)
                .padding(.trailing, 8)

            if let replies = attributedReplies {
                Text(replies)
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
            }

            Spacer()

            LikeButton(note: note)

            // Reply button
            Button(action: {
                router.push(ReplyToNavigationDestination(note: note))
            }, label: {
                Image.buttonReply
                    .padding(.leading, 10)
                    .padding(.trailing, 23)
                    .padding(.vertical, 12)
            })
        }
        .padding(.leading, 13)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                stops: [
                    Gradient.Stop(color: .storiesBgBottom.opacity(0), location: 0),
                    Gradient.Stop(color: .storiesBgBottom.opacity(1), location: 0.75),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .task {
            let context = persistenceController.newBackgroundContext()
            let (replyCount, replyAvatarURLs) = await Event.replyMetadata(
                for: note.identifier,
                context: context
            )
            self.replyCount = replyCount
            self.replyAvatarURLs = replyAvatarURLs
        }
    }

    private var attributedReplies: AttributedString? {
        if replyCount == 0 {
            return nil
        }
        let replyCount = replyCount
        let localized = replyCount == 1 ? Localized.Reply.one : Localized.Reply.many
        let string = localized.text(["count": "**\(replyCount)**"])
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: "\(replyCount)") {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
        }
    }
}
struct AuthorStoryView_Previews: PreviewProvider {
    
    static var previewData = PreviewData()
    @State static var cutoffDate = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
    
    static var previews: some View {
        NavigationView {
            AuthorStoryView(author: previewData.bob, cutoffDate: $cutoffDate, showPreviousAuthor: {}, showNextAuthor: {})
        }
        .inject(previewData: previewData)
    }
}
