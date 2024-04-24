import SwiftUI
import Dependencies

struct DiscoverGrid: View {
    @EnvironmentObject private var router: Router
    @FetchRequest(fetchRequest: Author.fetchRequest()) var authors: FetchedResults<Author>
    @ObservedObject var searchController: SearchController
    @Dependency(\.relayService) private var relayService

    // TODO: What's a better way to do this?
    @State private var subscriptions = [ObjectIdentifier: SubscriptionCancellable]()
    
    @State private var selectedCategory: FeaturedAuthorCategory = .all

    @Namespace private var animation

    /// Initializes a DiscoverGrid with the selected category and a search controller.
    /// - Parameters:
    ///   - featuredAuthorCategory: The initial category of featured authors to display until
    ///   the user changes the selection. Defaults to `.all` to show all featured authors.
    ///   - searchController: The search controller to use for searching.
    init(featuredAuthorCategory: FeaturedAuthorCategory = .all, searchController: SearchController) {
        self.selectedCategory = featuredAuthorCategory

        let authorsRequest = Author.allAuthorsRequest()
        authorsRequest.fetchLimit = 100
        authorsRequest.predicate = Author.matchingNpubsPredicate(npubs: featuredAuthorCategory.npubs)
        _authors = FetchRequest(fetchRequest: authorsRequest)

        self.searchController = searchController
    }
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                Group {
                    switch searchController.state {
                    case .noQuery:
                        ScrollView {
                            LazyVStack {
                                scrollingPicker

                                ForEach(authors) { author in
                                    AuthorCard(author: author) {
                                        router.push(author)
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.top, 5)
                                    .readabilityPadding()
                                    .task {
                                        // TODO: optimize. Probably only needed once per author.
                                        subscriptions[author.id] =
                                            await relayService.requestMetadata(
                                                for: author.hexadecimalPublicKey,
                                                since: author.lastUpdatedMetadata
                                            )
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        .doubleTapToPop(tab: .discover) { proxy in
                            if let firstAuthor = authors.first {
                                proxy.scrollTo(firstAuthor.id)
                            }
                        }
                    case .empty:
                        EmptyView()
                    case .loading, .stillLoading:
                        FullscreenProgressView(
                            isPresented: .constant(true),
                            text: searchController.state == .stillLoading ?
                            String(localized: .localizable.notFindingResults) : nil
                        )
                    case .results:
                        ScrollView {
                            LazyVStack {
                                ForEach(searchController.authorResults) { author in
                                    AuthorCard(author: author) {
                                        router.push(author)
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.top, 10)
                                    .readabilityPadding()
                                }
                            }
                            .padding(.top, 5)
                        }
                        .doubleTapToPop(tab: .discover) { proxy in
                            if let firstAuthor = searchController.authorResults.first {
                                proxy.scrollTo(firstAuthor.id)
                            }
                        }
                    }
                }
                .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        }
    }

    var scrollingPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(FeaturedAuthorCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }, label: {
                        Text(category.text)
                            .font(.footnote)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                selectedCategory == category ?
                                Color.pickerBackgroundSelected :
                                Color.clear
                            )
                            .foregroundColor(
                                selectedCategory == category ?
                                Color.primaryTxt :
                                Color.secondaryTxt
                            )
                            .cornerRadius(20)
                            .padding(4)
                    })
                }
            }
            .padding(.leading, 10)
            .onChange(of: selectedCategory) { _, newCategory in
                authors.nsPredicate = Author.matchingNpubsPredicate(npubs: newCategory.npubs)
            }
        }
        .scrollIndicatorsFlash(onAppear: true)
        .background(Color.profileBgTop)
    }
}
