//
//  UserModel.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 25.4.2024.
//

import Foundation
import Firebase
import FirebaseAuth

class AuthUser: ObservableObject {
    @Published var user: User?
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            self.user = user
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}


