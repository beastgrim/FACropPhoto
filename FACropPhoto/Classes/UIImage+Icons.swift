//
//  UIImage+Icons.swift
//  FACropPhoto_Example
//
//  Created by Евгений Богомолов on 25/11/2018.
//  Copyright © 2018 FaceApp. All rights reserved.
//

import UIKit


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
                
            case .r2x3, .r3x4, .r3x5, .r4x5, .r5x7, .r9x16:
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
    
}
