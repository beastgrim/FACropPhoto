//
//  UIImage+Icons.swift
//  FACropPhoto_Example
//
//  Created by Евгений Богомолов on 25/11/2018.
//  Copyright © 2018 FaceApp. All rights reserved.
//

import UIKit
import os.log


extension UIImage {

    public class func generateIcon(size: CGSize, aspectRatio: AspectRatio) -> UIImage {
        
        var image: UIImage
        
        image = UIImage.createImage(size: size, actions: { (context) in
            
            let frame = CGRect(origin: .zero, size: size)
            
            context.setLineWidth(0.5)
            context.setLineDash(phase: 4, lengths: [6,4])
            context.setStrokeColor(UIColor.white.cgColor)
            context.stroke(frame)
            
            context.setLineWidth(2)
            context.setLineDash(phase: 0, lengths: [])

            switch aspectRatio {
            case .r1x1:
                context.stroke(frame)
                
            default:
                let ratio = aspectRatio.ratio
                var frame = frame
                frame.size.height *= ratio
                frame.origin.y = (frame.width-frame.height)/2
                context.stroke(frame)
            }
        })

        return image
    }
    
    
    public class func createImage(size: CGSize,
                            scale: CGFloat = UIScreen.main.scale,
                            actions: (_: CGContext)->Void) -> UIImage
    {

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        if let context = UIGraphicsGetCurrentContext() {
            actions(context)
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
    
    
    public func crop(with cropRect: CGRect) -> UIImage {

        if Thread.isMainThread, #available(iOS 10.0, *) {
            os_log("[WARNING]: You should call this function in background thread!")
        }
        
        let image = self

        if let cgImage = image.cgImage {
            let orientation = image.imageOrientation
            let scale = image.scale
            var fullRect = CGRect(origin: .zero, size: image.size)
            fullRect.size.width *= scale
            fullRect.size.height *= scale
            // Apply orientation
            let cgCropRect = cropRect.appliedImageOrientation(orientation, with: fullRect.size)
            
            if let cropped = cgImage.cropping(to: cgCropRect) {
                let croppedImage = UIImage(cgImage: cropped,
                                           scale: image.scale,
                                           orientation: image.imageOrientation)
                return croppedImage
            }
        } else if let ciImage = image.ciImage {
            // Convert to another coordinate system (0,0) -> bottom,left
            var ciCropRect = cropRect
            ciCropRect.origin.y = ciImage.extent.height - cropRect.maxY
            
            if let cgImage = CIContext().createCGImage(ciImage, from: ciCropRect) {
                let croppedImage = UIImage(cgImage: cgImage,
                                           scale: image.scale,
                                           orientation: image.imageOrientation)
                
                return croppedImage
            }
        } else {
            if #available(iOS 10.0, *) {
                os_log("[ERROR] %@: Image not supported: %@", #function, image)
            }
        }
        
        return image
    }
}
