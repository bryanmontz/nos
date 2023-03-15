//
//  ProfileEditView.swift
//  Nos
//
//  Created by Christopher Jorgensen on 3/9/23.
//

import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject private var relayService: RelayService
    @EnvironmentObject private var router: Router
    @Environment(\.managedObjectContext) private var viewContext

    var author: Author
    
    @State private var displayNameText: String = ""
    @State private var nameText: String = ""
    @State private var bioText: String = ""
    @State private var avatarText: String = ""
    @State private var nip05Text: String = ""
    
    var createAccountCompletion: (() -> Void)?
    
    init(author: Author, createAccountCompletion: (() -> Void)? = nil) {
        self.author = author
        self.createAccountCompletion = createAccountCompletion
    }
    
    var body: some View {
        VStack {
            Form {
                Section {
                    TextField(text: $displayNameText) {
                        Localized.displayName.view.foregroundColor(.secondaryTxt)
                    }
                    .textInputAutocapitalization(.none)
                    .foregroundColor(.textColor)
                    .autocorrectionDisabled()
                    TextField(text: $nameText) {
                        Localized.name.view.foregroundColor(.secondaryTxt)
                    }
                    .textInputAutocapitalization(.none)
                    .foregroundColor(.textColor)
                    .autocorrectionDisabled()
                    TextEditor(text: $bioText)
                        .placeholder(when: bioText.isEmpty, placeholder: {
                            Text(Localized.bio.string)
                                .foregroundColor(.secondaryTxt)
                        })
                        .foregroundColor(.textColor)
                    TextField(text: $avatarText) {
                        Localized.picUrl.view.foregroundColor(.secondaryTxt)
                    }
                    .foregroundColor(.textColor)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.none)
                    #if os(iOS)
                    .keyboardType(.URL)
                    #endif
                    TextField(text: $nip05Text) {
                        Localized.nip05.view.foregroundColor(.secondaryTxt)
                    }
                    .textInputAutocapitalization(.none)
                    .foregroundColor(.textColor)
                    .autocorrectionDisabled()
                } header: {
                    createAccountCompletion != nil ? Localized.createAccount.view : Localized.basicInfo.view
                        .foregroundColor(.textColor)
                        .fontWeight(.heavy)
                }
                .listRowBackground(LinearGradient(
                    colors: [Color.cardBgTop, Color.cardBgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
            if let createAccountCompletion {
                Spacer()
                BigActionButton(title: .createAccount) {
                    save()
                    createAccountCompletion()
                }
                .background(Color.appBg)
                .padding(.horizontal, 24)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBg)
        .navigationBarItems(
            trailing:
                Group {
                    if createAccountCompletion == nil {
                        Button(
                            action: {
                                save()
                                
                                // Go back to profile page
                                router.pop()
                            },
                            label: {
                                Text(Localized.done.string)
                            }
                        )
                    }
                }
        )
        .task {
            displayNameText = author.displayName ?? ""
            nameText = author.name ?? ""
            bioText = author.about ?? ""
            avatarText = author.profilePhotoURL?.absoluteString ?? ""
            nip05Text = author.nip05 ?? ""
        }
        .onDisappear {
            CurrentUser.shared.editing = false
        }
    }
    
    func save() {
        author.displayName = displayNameText
        author.name = nameText
        author.about = bioText
        author.profilePhotoURL = URL(string: avatarText)
        author.nip05 = nip05Text
        // Post event
        CurrentUser.shared.publishMetaData()
    }
}

struct ProfileEditView_Previews: PreviewProvider {
    
    static var persistenceController = PersistenceController.preview
    static var previewContext = persistenceController.container.viewContext

    static var author: Author {
        let author = Author(context: previewContext)
        author.hexadecimalPublicKey = KeyFixture.pubKeyHex
        return author
    }
    
    static var previews: some View {
        ProfileEditView(author: author)
    }
}
