//
//  SideMenuContent.swift
//  Nos
//
//  Created by Jason Cheatham on 2/21/23.
//
import SwiftUI
import MessageUI

struct SideMenuContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @EnvironmentObject var router: Router
    
    @State private var isShowingReportABugMailView = false
    
    @State var result: Result<MFMailComposeResult, Error>?
    
    let closeMenu: () -> Void
    
    var body: some View {
        NavigationStack(path: $router.sideMenuPath) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                HStack {
                    Button {
                        do {
                            guard let keyPair = KeyPair.loadFromKeychain() else { return }
                            let author = try Author.findOrCreate(by: keyPair.publicKeyHex, context: viewContext)
                            router.sideMenuPath.append(SideMenu.Destination.profile)
                        } catch {
                            // Replace this implementation with code to handle the error appropriately.
                            let nsError = error as NSError
                            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                        }
                    } label: {
                        HStack(alignment: .center) {
                            Image(systemName: "person.crop.circle")
                            Text("Your Profile")
                                .foregroundColor(.primaryTxt)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                HStack {
                    Button {
                        router.sideMenuPath.append(SideMenu.Destination.settings)
                    } label: {
                        HStack(alignment: .center) {
                            Image(systemName: "gear")
                            Text("Settings")
                                .foregroundColor(.primaryTxt)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                HStack {
                    Button {
                        router.sideMenuPath.append(SideMenu.Destination.relays)
                    } label: {
                        HStack(alignment: .center) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Localized.relays.view
                                .foregroundColor(.primaryTxt)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                HStack {
                    Button {
                    } label: {
                        HStack(alignment: .center) {
                            Image(systemName: "questionmark.circle")
                            Text("Help and Support")
                                .foregroundColor(.primaryTxt)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                HStack {
                    Button {
                        isShowingReportABugMailView = true
                    } label: {
                        HStack(alignment: .center) {
                            Image(systemName: "ant.circle.fill")
                            Text("Report a Bug")
                                .foregroundColor(.primaryTxt)
                        }
                    }
                    .disabled(!MFMailComposeViewController.canSendMail())
                    .sheet(isPresented: $isShowingReportABugMailView) {
                        ReportABugMailView(result: self.$result)
                    }
                    
                    Spacer()
                }
                .padding()
                Spacer(minLength: 0)
            }
            .background(Color.appBg)
            .navigationDestination(for: SideMenu.Destination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView()
                case .relays:
                    RelayView(author: CurrentUser.author!)
                case .profile:
                    ProfileView(author: CurrentUser.author!)
                }
            }
        }
    }
}
