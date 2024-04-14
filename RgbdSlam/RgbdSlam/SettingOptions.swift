//
//  SettingOptions.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 14.4.2024.
//

import Foundation

let ColorRadiusOptions: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label:"30 cm", value: 0.3),
    SettingPickerOption<Float>(label:"20 cm", value: 0.2),
    SettingPickerOption<Float>(label:"10 cm", value: 0.1),
    SettingPickerOption<Float>(label:"5 cm", value: 0.05),
    SettingPickerOption<Float>(label:"2.5 cm", value: 0.025),
    SettingPickerOption<Float>(label:"2 cm", value: 0.02),
    SettingPickerOption<Float>(label:"1.5 cm", value: 0.015),
    SettingPickerOption<Float>(label:"1 cm", value: 0.01),
]

let NoiseRatioOptions: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label:"Keep Largest Only", value: 1),
    SettingPickerOption<Float>(label:"0.9", value: 0.9),
    SettingPickerOption<Float>(label:"0.8", value: 0.8),
    SettingPickerOption<Float>(label:"0.7", value: 0.7),
    SettingPickerOption<Float>(label:"0.6", value: 0.6),
    SettingPickerOption<Float>(label:"0.5", value: 0.5),
    SettingPickerOption<Float>(label:"0.4", value: 0.4),
    SettingPickerOption<Float>(label:"0.3", value: 0.3),
    SettingPickerOption<Float>(label:"0.2", value: 0.2),
    SettingPickerOption<Float>(label:"0.1", value: 0.1),
    SettingPickerOption<Float>(label:"0.05", value: 0.05),
    SettingPickerOption<Float>(label:"0.01", value: 0.01)
    
]

let PointSizeOptions: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label: "50", value: 50),
    SettingPickerOption<Float>(label: "30", value: 30),
    SettingPickerOption<Float>(label: "25", value: 25),
    SettingPickerOption<Float>(label: "15", value: 15),
    SettingPickerOption<Float>(label: "10", value: 10),
    SettingPickerOption<Float>(label: "5", value: 5),
    SettingPickerOption<Float>(label: "1", value: 1),
]

let BgColorOption: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label: "0.9", value: 0.9),
    SettingPickerOption<Float>(label: "Light Grey", value: 0.8),
    SettingPickerOption<Float>(label: "0.7", value: 0.7),
    SettingPickerOption<Float>(label: "0.6", value: 0.6),
    SettingPickerOption<Float>(label: "Grey", value: 0.5),
    SettingPickerOption<Float>(label: "0.4", value: 0.4),
    SettingPickerOption<Float>(label: "0.3", value: 0.3),
    SettingPickerOption<Float>(label: "Dark Grey", value: 0.2),
    SettingPickerOption<Float>(label: "0.1", value: 0.1),
    SettingPickerOption<Float>(label: "Black", value: 0),
]

let TextureOptions: [SettingPickerOption<Int>] = [
    SettingPickerOption<Int>(label: "Maximum", value: 1),
    SettingPickerOption<Int>(label: "High", value: 2),
    SettingPickerOption<Int>(label: "Low", value: 4),
    SettingPickerOption<Int>(label: "Very Low", value: 8),
]

let MeshDeciOption: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label: "99%", value: 0.99),
    SettingPickerOption<Float>(label: "95%", value: 0.95),
    SettingPickerOption<Float>(label: "90%", value: 0.9),
    SettingPickerOption<Float>(label: "80", value: 0.8),
    SettingPickerOption<Float>(label: "70", value: 0.7),
    SettingPickerOption<Float>(label: "60%", value: 0.6),
    SettingPickerOption<Float>(label: "50%", value: 0.5),
    SettingPickerOption<Float>(label: "40%", value: 0.4),
    SettingPickerOption<Float>(label: "30", value: 0.3),
    SettingPickerOption<Float>(label: "20%", value: 0.2),
    SettingPickerOption<Float>(label: "10%", value: 0.1),
    SettingPickerOption<Float>(label: "Disabled", value: 0),
]

let MeshTriOptions: [SettingPickerOption<Int>] = [6, 5, 4 ,3 ,2 ].map { id -> SettingPickerOption<Int> in
    SettingPickerOption<Int>(label: "\(id) pix", value: id)
}

let MeshAngTolOption: [SettingPickerOption<Int>] = [60, 45, 35, 30, 25, 20, 15, 10, 5].map { id -> SettingPickerOption<Int> in
    SettingPickerOption<Int>(label: "\(id)", value: id)
}

let DepthConOption: [SettingPickerOption<Int>] = [
    SettingPickerOption<Int>(label: "High", value: 2),
    SettingPickerOption<Int>(label: "Medium", value: 1),
    SettingPickerOption<Int>(label: "Low", value: 0)
]

let MinDepthOptions: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label:"0 m", value: 0),
    SettingPickerOption<Float>(label:"0.3 m", value: 0.3),
    SettingPickerOption<Float>(label:"0.5 m", value: 0.5),
    SettingPickerOption<Float>(label:"0.75 m", value: 0.75),
    SettingPickerOption<Float>(label:"1 m", value: 1),
    SettingPickerOption<Float>(label:"1.5 m", value: 1.5),
    SettingPickerOption<Float>(label:"2 m", value: 2),
    SettingPickerOption<Float>(label:"2.5 m", value: 2.5),
    SettingPickerOption<Float>(label:"3 m", value: 3),
]

let MaxDepOptions: [SettingPickerOption<Float>] = [
    SettingPickerOption<Float>(label:"No Limit", value: 0),
    SettingPickerOption<Float>(label:"5 m", value: 5),
    SettingPickerOption<Float>(label:"4.5 m", value: 4.5),
    SettingPickerOption<Float>(label:"4 m", value: 4),
    SettingPickerOption<Float>(label:"3.5 m", value: 3.5),
    SettingPickerOption<Float>(label:"3 m", value: 3),
    SettingPickerOption<Float>(label:"2.5 m", value: 2.5),
    SettingPickerOption<Float>(label:"2 m", value: 2),
    SettingPickerOption<Float>(label:"1.5 m", value: 1.5),
    SettingPickerOption<Float>(label:"1 m", value: 1)
]

let PCDenOption: [SettingPickerOption<Int>] = [
    SettingPickerOption<Int>(label: "Maximum", value: 0),
    SettingPickerOption<Int>(label: "High", value: 1),
    SettingPickerOption<Int>(label: "Low", value: 2),
    SettingPickerOption<Int>(label: "Very Low", value: 3),
]
