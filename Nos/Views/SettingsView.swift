//
//  SettingsView.swift
//  Nos
//
//  Created by Matthew Lorentz on 2/3/23.
//

import SwiftUI

struct SettingsView: View {
    @State private var keyPair: KeyPair? {
        didSet {
            if let pair = keyPair {
                let privateKey = Data(pair.privateKeyHex.utf8)
                let publicStatus = KeyChain.save(key: KeyChain.keychainPrivateKey, data: privateKey)
                print("Public key keychain storage status: \(publicStatus)")
            }
        }
    }
    
    @State var privateKeyString = ""
    
    @State var showError = false
    
    var body: some View {
        Form {
            Section(Localized.keys.string) {
                Localized.keyEncryptionWarning.view
                TextField(Localized.privateKeyPlaceholder.string, text: $privateKeyString)
                Button(Localized.save.string) {
                    if let keyPair = KeyPair(privateKeyHex: privateKeyString) {
                        self.keyPair = keyPair
                    } else {
                        self.keyPair = nil
                        showError = true
                    }
                }
            }
        }
        .navigationTitle(Localized.settings.string)
        .alert(isPresented: $showError) {
            Alert(
                title: Localized.invalidKey.view,
                message: Localized.couldNotReadPrivateKeyMessage.view
            )
        }
        .task {
			if let privateKeyData = KeyChain.load(key: KeyChain.keychainPrivateKey) {
				let hexString = String(decoding: privateKeyData, as: UTF8.self)
                privateKeyString = hexString
            } else {
                print("Could not load private key from keychain")
                privateKeyString = ""
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
        }
    }
}
