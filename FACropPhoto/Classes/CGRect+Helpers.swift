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
            r = r.croppedBy(y: side)
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
}

extension CGSize {
    
    func scaleToFit(to size: CGSize) -> CGFloat {
        return min(size.width/self.width, size.height/self.height)
    }
    
    func scaleToFill(to size: CGSize) -> CGFloat {
        return max(size.width/self.width, size.height/self.height)
    }
}
