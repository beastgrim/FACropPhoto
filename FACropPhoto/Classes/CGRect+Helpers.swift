//
//  CGRect+Helpers.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 21/11/2018.
//

import UIKit

extension CGRect {
    
    func extendTo(minSize: CGSize) -> CGRect {
        var r = self
        if r.size.width < minSize.width {
            r.size.width = minSize.width
        }
        if r.size.height < minSize.height {
            r.size.height = minSize.height
        }
        return r
    }
    
    func with(width: CGFloat, options: UIRectEdge = []) -> CGRect {
        var r = self
        if options.contains(.right) {
            r.origin.x += r.width-width
        }
        r.size.width = width
        return r
    }
    
    func with(height: CGFloat, options: UIRectEdge = []) -> CGRect {
        var r = self
        if options.contains(.bottom) {
            r.origin.y += r.height-height
        }
        r.size.height = height
        return r
    }
    
    func croppedBy(side: CGFloat, options: UIRectEdge = .all) -> CGRect {
        var r = self
        if options.contains(.top) {
            r = r.croppedBy(y: side)
        }
        if options.contains(.left) {
            r = r.croppedBy(x: side)
        }
        if options.contains(.bottom) {
            r.size.height -= side
        }
        if options.contains(.right) {
            r.size.width -= side
        }
        return r
    }
    
    func croppedBy(y: CGFloat) -> CGRect {
        var r = self
        r.size.height = r.height-y
        r.origin.y = y
        return r
    }
    
    func croppedBy(x: CGFloat) -> CGRect {
        var r = self
        r.size.width = r.width-x
        r.origin.x = x
        return r
    }
    
    func scaleToFit(to size: CGSize) -> CGFloat {
        return self.size.scaleToFit(to: size)
    }
    
    func appliedImageOrientation(_ imageOrientation: UIImage.Orientation, with imageSize: CGSize) -> CGRect {
        
        var rect = self
        switch imageOrientation {
        case .up,.upMirrored: break

        case .right,.rightMirrored:
            let size = CGSize(width: rect.size.height, height: rect.size.width)
            let origin = CGPoint(x: rect.origin.y, y: imageSize.width - rect.maxX)
            rect = CGRect(origin: origin, size: size)
        case .left,.leftMirrored:
            let size = CGSize(width: rect.size.height, height: rect.size.width)
            let origin = CGPoint(x: imageSize.height - rect.maxY, y: rect.origin.x)
            rect = CGRect(origin: origin, size: size)
        case .down,.downMirrored:
            let size = rect.size
            let origin = CGPoint(x: imageSize.width - rect.maxX, y: imageSize.height - rect.maxY)
            rect = CGRect(origin: origin, size: size)
        }
        
        return rect
    }
}

extension CGSize {
    
    func scaleToFit(to size: CGSize) -> CGFloat {
        return min(size.width/self.width, size.height/self.height)
    }
    
    func scaleToFill(to size: CGSize) -> CGFloat {
        return max(size.width/self.width, size.height/self.height)
    }
    
    func minus(size: CGSize) -> CGSize {
        var r = self
        r.width -= size.width
        r.height -= size.height
        return r
    }
    
    func minus(point: CGPoint) -> CGSize {
        var r = self
        r.width -= point.x
        r.height -= point.y
        return r
    }
}
