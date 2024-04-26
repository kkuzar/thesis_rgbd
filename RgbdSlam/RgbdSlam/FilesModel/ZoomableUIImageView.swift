//
//  ZoomableUIImageView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 26.4.2024.
//
import Foundation
import UIKit
import Combine
import SwiftUI

//
//struct ZoomableImageViewWrapper: UIViewControllerRepresentable {
//    var uiImage: UIImage
//    // var contentMode: UIView.ContentMode
//    
//    func makeUIViewController(context: Context) -> ZoomableImageViewController {
//        let vc = ZoomableImageViewController()
//        let imageView = UIImageView(image: uiImage)
////        imageView.contentMode = .scaleAspectFit
//        imageView.clipsToBounds = true
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        
//        vc.imageView = imageView
//        
//        return vc
//    }
//
//    func updateUIViewController(_ uiViewController: ZoomableImageViewController, context: Context) {
//        // Update the UI if needed
//    }
//}
//
//
//
//class ZoomableImageViewController: UIViewController, UIScrollViewDelegate {
//    var imageView = UIImageView!
//    var scrollView = UIScrollView()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // Setup the image view with an image
//        
//        imageView.contentMode = .center
//        imageView.isUserInteractionEnabled = true
//        
//        // Setup the scroll view
//        scrollView.delegate = self
//        scrollView.addSubview(imageView)
//        scrollView.maximumZoomScale = 3.0
//        scrollView.minimumZoomScale = 1.0
//        view.addSubview(scrollView)
//    }
//    
//    override func viewWillLayoutSubviews() {
//        super.viewWillLayoutSubviews()
//        scrollView.frame = view.bounds
//        imageView.frame = CGRect(x: 0, y: 0, width: scrollView.frame.width, height: scrollView.frame.height)
//        scrollView.contentSize = imageView.bounds.size
//        centerImage()
//    }
//
//    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
//        return imageView
//    }
//
//    func centerImage() {
//        let scrollViewSize = scrollView.bounds.size
//        let imageSize = imageView.frame.size
//        let horizontalSpace = imageSize.width < scrollViewSize.width ? (scrollViewSize.width - imageSize.width) / 2 : 0
//        let verticalSpace = imageSize.height < scrollViewSize.height ? (scrollViewSize.height - imageSize.height) / 2 : 0
//        scrollView.contentInset = UIEdgeInsets(top: verticalSpace, left: horizontalSpace, bottom: verticalSpace, right: horizontalSpace)
//    }
//
//    func scrollViewDidZoom(_ scrollView: UIScrollView) {
//        centerImage()
//    }
//}
