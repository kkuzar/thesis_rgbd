//
//  SettingsUtil.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 14.4.2024.
//

import Foundation


struct SettingPickerOption<T>: Identifiable {
    var id: String {label}
    let label : String
    let value: T
}

