//
//  RgbdSlamApp.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 12.4.2024.
//

import SwiftUI
import SwiftData
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct RgbdSlamApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    
    var body: some Scene {
        
        WindowGroup {
            SplashScreenView()
        }
        
    }
}

func setUserDefaultsFromPlist() {
    let mappingDefaults = ["Root", "Mapping", "Assembling"]

    for plistName in mappingDefaults {
        NSLog("plist name is \(plistName)");
        if let settingsURL = Bundle.main.url(forResource: plistName, withExtension: "plist"),
            let settingsPlist = NSDictionary(contentsOf: settingsURL),
            let preferences = settingsPlist["PreferenceSpecifiers"] as? [NSDictionary] {



            for prefSpecification in preferences {

                if let key = prefSpecification["Key"] as? String, let value = prefSpecification["DefaultValue"] {

                    //If key doesn't exists in userDefaults then register it, else keep original value
                    if UserDefaults.standard.value(forKey: key) == nil {

                        UserDefaults.standard.set(value, forKey: key)
                        NSLog("registerDefaultsFromSettingsBundle: Set following to UserDefaults - (key: \(key), value: \(value), type: \(type(of: value)))")
                    }
                }
            }
        } else {
            NSLog("registerDefaultsFromSettingsBundle: Could not find Settings.bundle")
        }
    }

}
