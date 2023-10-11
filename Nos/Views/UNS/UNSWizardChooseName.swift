//
//  UNSWizardChooseName.swift
//  Nos
//
//  Created by Matthew Lorentz on 9/29/23.
//

import SwiftUI
import Dependencies
import Logger

fileprivate struct PickerRow<Label: View>: View {
    @Binding var isSelected: Bool
    var label: Label
    
    init(isSelected: Binding<Bool>, @ViewBuilder builder: () -> Label) {
        self._isSelected = isSelected
        self.label = builder()
    }
    
    var body: some View {
        HStack {
                if isSelected {
                    Circle()
                        .foregroundStyle(LinearGradient.verticalAccent)
                        .frame(width: 16, height: 16)
                } else {
                    Circle()
                        .stroke(Color.secondaryAction)
                        .frame(width: 16, height: 16)
                }
            
            if isSelected {
                label.foregroundStyle(LinearGradient.verticalAccent) 
            } else {
                label.foregroundStyle(Color.primaryTxt) 
            }
            
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
    }
}

struct UNSWizardChooseName: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @Dependency(\.analytics) var analytics
    @Dependency(\.unsAPI) var api
    @Dependency(\.currentUser) var currentUser 
    @Binding var context: UNSWizardContext
    @State var selectedName: UNSNameRecord?
    @State var desiredName: UNSName = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    //                    UNSStepImage { Image.unsOTP.offset(x: 7, y: 5) }
                    //                        .padding(40)
                    //                        .padding(.top, 50)
                    //                    
                    //                    PlainText(.verification)
                    //                        .font(.clarityTitle)
                    //                        .multilineTextAlignment(.center)
                    //                        .foregroundColor(.primaryTxt)
                    //                        .shadow(radius: 1, y: 1)
                    
                    
                    VStack {
                        
                        if let names = context.names {
                            ForEach(names) { name in
                                Button { 
                                    selectedName = name
                                    desiredName = ""
                                } label: { 
                                    let isSelected = Binding { 
                                        selectedName == name && desiredName.isEmpty
                                    } set: { isSelected in
                                        if isSelected {
                                            selectedName = name
                                        } else {
                                            selectedName = nil
                                        }
                                    }

                                    PickerRow(isSelected: isSelected) {
                                        PlainText(name.name)
                                            .font(.clarityTitle2)
                                    }
                                }
                            }
                            .onAppear {
                                selectedName = names.first
                            }
                        }
                        
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.secondaryAction)

                        let isSelected = Binding { 
                            !desiredName.isEmpty
                        } set: { newValue in
                            
                        }

                        PickerRow(isSelected: isSelected) { 
                            PlainTextField(text: $desiredName) {
                                PlainText(.createNewName)
                                    .foregroundColor(.secondaryText)
                            }
                            .font(.clarityTitle2)
                            .foregroundStyle(LinearGradient.verticalAccent)
                            .foregroundColor(.primaryTxt)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.none)
                            .padding(19)
                            Spacer()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondaryAction, lineWidth: 2)
                            .background(Color.textFieldBg)
                    )
                    
                    Spacer()
                    
                    BigActionButton(title: .next) {
                        await submit()
                    }
                    .padding(.bottom, 41)
                }
                .padding(.horizontal, 38)
                .readabilityPadding()
            }
            .background(Color.appBg)
        }    
    }
    
    @MainActor func submit() async {
        do {
            if !desiredName.isEmpty {
                try await register(desiredName: desiredName)
            } else if let selectedName {
                context.nameRecord = selectedName
                var nip05: String
                if let message = try await api.requestNostrVerification(
                    npub: currentUser.keyPair!.npub,
                    nameID: context.nameRecord!.id
                ) {
                    nip05 = try await api.submitNostrVerification(
                        message: message,
                        keyPair: currentUser.keyPair!
                    )
                } else {
                    nip05 = try await api.getNIP05(for: context.nameRecord!.id)
                }
                try await saveDetails(name: selectedName.name, nip05: nip05)
            }
        } catch {
            Log.optional(error)
            context.state = .error
        }
    }
    
    func register(desiredName: UNSName) async throws {
        context.state = .loading
        analytics.choseUNSName()
        do {
            let response = try await api.createName(
                // TODO: sanitize somewhere else
                desiredName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            ) 
            
            switch response {
            case.left(let nameID):
                context.nameRecord = UNSNameRecord(name: desiredName, id: nameID)
            case .right(let paymentURL):
                // TODO: open URL
                context.state = .needsPayment(paymentURL)
                return
            }
            let message = try await api.requestNostrVerification(
                npub: currentUser.keyPair!.npub, 
                nameID: context.nameRecord!.id
            )!
            let nip05 = try await api.submitNostrVerification(
                message: message,
                keyPair: currentUser.keyPair!
            )
            try await saveDetails(name: desiredName, nip05: nip05)
        } catch {
            if case let UNSError.requiresPayment(paymentURL) = error {
                print("go to \(paymentURL) to complete payment")
            } else {
                // TODO: show generic error message if the name isn't taken
                context.state = .nameTaken
                return
            }
        }
    }
    
    @MainActor func saveDetails(name: String, nip05: String) async throws {
        let author = currentUser.author
        author?.name = name
        author?.nip05 = nip05
        try viewContext.save()
        await currentUser.publishMetaData()
        context.state = .success
    }
}

#Preview {
    
    var previewData = PreviewData()
    @State var context = UNSWizardContext(
        state: .chooseName, 
        authorKey: previewData.alice.hexadecimalPublicKey!,
        names: [
            UNSNameRecord(name: "Fred", id: "1"),
            UNSNameRecord(name: "Sally", id: "2"),
            UNSNameRecord(name: "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.", id: "3"),
        ]
    )
    
    return UNSWizardChooseName(context: $context)
}
