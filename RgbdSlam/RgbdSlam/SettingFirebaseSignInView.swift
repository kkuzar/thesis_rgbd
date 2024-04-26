//
//  SettingFirebaseSignInView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 25.4.2024.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct SettingFirebaseSignInView: View {
    
    @State private var selection = 0
    @State private var email = ""
    @State private var password = ""
    
    @State private var showAlert = false
    @State private var alertMessage = "Logged in successfully!"
    @State private var isLoggedIn = false
    
    var body: some View {
        VStack {
            if isLoggedIn {
                ContentView()
            } else {
                Section {
                    Picker("Options", selection: $selection) {
                        Text("Sign In").tag(0)
                        Text("Sign Up").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                } .padding()
                
                if selection == 0 {
                    List {
                        Section {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            SecureField("Password", text: $password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                        }
                        
                        Section {
                            Button(action: signIn) {
                                Text("Sign In")
                            }
                        }
                        
                    }
                    
                } else {
                    List {
                        Section {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            SecureField("Password", text: $password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                        }
                        Section {
                            Button(action: signUp) {
                                Text("Sign Up")
                            }
                        }
                    }
                }
            }
            
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Login Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")){
                isLoggedIn = true  // Navigate to ContentView
            })
        }
    }
    
    // functions below
    func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { (result, error) in
            if let error = error {
                self.alertMessage = error.localizedDescription
                self.showAlert = true
            } else {
                self.alertMessage = "Logged in successfully!"
                self.showAlert = true
                // Proceed with navigating to the next part of your app
                
            }
        }
    }
    
    func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
            if let error = error {
                self.alertMessage = error.localizedDescription
                self.showAlert = true
            } else {
                self.alertMessage = "Logged in successfully!"
                self.showAlert = true
                
            }
        }
    }
    
}


#Preview {
    SettingFirebaseSignInView()
}
