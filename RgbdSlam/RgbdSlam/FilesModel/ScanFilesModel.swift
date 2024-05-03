//
//  ScanFileModel.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 25.4.2024.
//

import Foundation
import UIKit
import Combine
import SwiftUI


struct UIImageViewWrapper: UIViewRepresentable {
    var uiImage: UIImage
    var contentMode: UIView.ContentMode
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Update the UIImageView if needed
        uiView.image = uiImage
        uiView.contentMode = contentMode
    }
}

let RTABMAP_TMP_DB = "rtabmap.tmp.db"
let RTABMAP_RECOVERY_DB = "rtabmap.tmp.recovery.db"
let RTABMAP_EXPORT_DIR = "Export"

class ScanLibarayObject {
    var scanThumbnail: UIImage?
    var scanName: String
    var scanPath: URL
    var scanSize: UInt64
    var scanSizeString: String
    var scanDate: Date?
    var scanAttr: Any?
    
    
    init(pathURL: URL) {
        // super.init(frame: frame)
        self.scanPath = pathURL
        self.scanName = URL(fileURLWithPath: pathURL.path).lastPathComponent
        self.scanSize = URL(fileURLWithPath: pathURL.path).fileSize
        self.scanSizeString = URL(fileURLWithPath: pathURL.path).fileSizeString
        self.scanDate = URL(fileURLWithPath: pathURL.path).creationDate
        self.scanAttr = URL(fileURLWithPath: pathURL.path).attributes
        
        DispatchQueue.global(qos: .background).async {
            let loadedImage = getPreviewImage(databasePath: self.scanPath.path)
            DispatchQueue.main.async {
                self.scanThumbnail = loadedImage
            }
        }
    }
    
}


class ChosenScan: ObservableObject {
    @Published var filePath: String?
    
}

class ScanFilesModel: ObservableObject {
    @Published var scanFiles: [ScanLibarayObject] = []
    @Published var fileURL: [URL]?
    
    private var rtabmap: RTABMap?
    
    init() {
        // self.fileList = fetchDatabaseFiles()
        let existScan: [URL] = getExistScan()
        self.fileURL = existScan
        initScanLibObj(scansUrl:existScan)
    }
    
    deinit {
        
    }
    
    func refresh() {
        let existScan: [URL] = getExistScan()
        self.fileURL = existScan
        initScanLibObj(scansUrl:existScan)
    }
    
    func getDocumentDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func initScanLibObj (scansUrl: [URL]) {
        scansUrl.forEach{ fileUrl in
            self.scanFiles.append(ScanLibarayObject(pathURL: fileUrl))
        }
    }
    
    func getExistScan() -> [URL] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: getDocumentDirectory(), includingPropertiesForKeys: nil)
            // if you want to filter the directory contents you can do like this:
            
            let data = fileURLs.map { url in
                (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
            }
                .sorted(by: { $0.1 > $1.1 }) // sort descending modification dates
                .map { $0.0 } // extract file names
            return data.filter{ $0.pathExtension == "db" && $0.lastPathComponent != RTABMAP_TMP_DB && $0.lastPathComponent != RTABMAP_RECOVERY_DB }
            
        } catch {
            print("Error while enumerating files : \(error.localizedDescription)")
            return []
        }
    }
    
    func rename(fileURL: URL) {
//        if !FileManager.default.fileExists(atPath: filePath) {
//            do {
//                try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: filePath))
//                print("File \(fileURL) renamed to \(filePath)")
//            }
//            catch {
//                print("Error renaming file \(fileURL) to \(filePath)")
//            }
//        }
    }
    
    func upload() {
        
    }
    
    func remove(fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("File \(fileURL) deleted")
        }
        catch {
            print("Error deleting file \(fileURL)")
        }
    }

}

