//
//  SideMenuView.swift
//  Nos
//
//  Created by Jason Cheatham on 2/21/23.
//

import Foundation
import SwiftUI
import Dependencies

struct SideMenu: View {
    
    enum Destination {
        case settings
        case relays
        case profile
        case about
    }
    
    let menuWidth: CGFloat
    let menuOpened: Bool
    
    let toggleMenu: () -> Void
    let closeMenu: () -> Void
    
    @EnvironmentObject private var router: Router
    @Dependency(\.analytics) private var analytics
    
    var body: some View {
        if menuOpened {
            ZStack {
                GeometryReader { _ in
                    EmptyView()
                }
                .background(Color.black.opacity(0.5))
                .onTapGesture {
                    self.toggleMenu()
                }
            }
            HStack {
                SideMenuContent(closeMenu: closeMenu)
                    .frame(
                        maxWidth: router.sideMenuPath.count == 0 ? menuWidth : .infinity,
                        maxHeight: .infinity
                    )
                Spacer()
            }
            .transition(.move(edge: .leading))
            // weirdly fixes dismissal animation
            // https://sarunw.com/posts/how-to-fix-zstack-transition-animation-in-swiftui/#solution
            .zIndex(1)
            .onAppear {
                analytics.showedSideMenu()
            }
        }
    }
}
