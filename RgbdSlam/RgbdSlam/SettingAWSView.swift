//
//  SettingAWSView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 15.4.2024.
//

import SwiftUI
import Combine
import KeychainSwift

class SettingAwsDataModel: ObservableObject {
    
    // static let shared = SettingAwsDataModel()
    let keychain = KeychainSwift()
    @Published var appID: String = ""
    @Published var appKey: String = ""
    
    @Published var s3KeyExist: Bool {
        didSet {
            UserDefaults.standard.set(self.s3KeyExist, forKey: "s3KeyExist")
        }
    }
    
    init() {
        s3KeyExist = UserDefaults.standard.bool(forKey: "s3KeyExist")
        appID = keychain.get("s3AppID") ?? ""
    }
    
    func reset () {
        appID = ""
        appKey = ""
        s3KeyExist = false
        keychain.delete("s3AppID")
        keychain.delete("s3AppKey")
    }
    
    func save() {
        keychain.set(appID, forKey: "s3AppID")
        keychain.set(appKey, forKey: "s3AppKey")
        s3KeyExist = true
        appKey = ""
    }
    
    func debug() {
        
        let id = keychain.get("s3AppID") ?? ""
        let key = keychain.get("s3AppKey") ?? ""
        
        NSLog("\(id)")
        NSLog("\(key)")
        NSLog("\(s3KeyExist)")
    }
}

struct SettingAWSView: View {
    
    @StateObject var model = SettingAwsDataModel()
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Insert AWS Config") {
                    TextField("AWS ID", text: $model.appID)
                    
                    if !model.s3KeyExist {
                        if isPasswordVisible {
                            TextField("Password", text: $model.appKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Password", text: $model.appKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    } else {
                        Text("Key exist, please validate or reset")
                    }
                    
                    
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
                Section {
                    if !model.s3KeyExist {
                        Button("Save") {
                            model.save()
                        }
                    } else {
                        Button("Reset") {
                            model.reset()
                        }.foregroundColor(.red)
                    }
                    
                    Button("Debug") {
                        model.debug()
                    }.foregroundColor(.yellow)
                }
            }
        }
    }
}

#Preview {
    SettingAWSView()
}
