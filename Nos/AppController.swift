//
//  AppController.swift
//  Nos
//
//  Created by Shane Bielefeld on 2/15/23.
//

import Foundation
import Dependencies

class AppController: ObservableObject {
    enum CurrentState {
        case onboarding
        case loggedIn
    }
    
    @Published private(set) var currentState: CurrentState?
    
    @Dependency(\.analytics) private var analytics
    
    func configureCurrentState() {
        currentState = KeyChain.load(key: KeyChain.keychainPrivateKey) == nil ? .onboarding : .loggedIn
    }
    
    func completeOnboarding() {
        currentState = .loggedIn
        analytics.completedOnboarding()
    }
}
