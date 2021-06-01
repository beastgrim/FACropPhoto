//
//  FAMaskView.swift
//  FACropPhoto_Example
//
//  Created by Евгений Богомолов on 24/11/2018.
//  Copyright © 2018 FaceApp. All rights reserved.
//

import UIKit

internal class FAMaskView: UIView {
    
    lazy var shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.white.cgColor
        layer.frame = self.bounds
        layer.fillRule = CAShapeLayerFillRule.evenOdd
        self.layer.addSublayer(layer)
        return layer
    }()
    
    
    private(set) var cropRect: CGRect = .zero
    
    public func setCropRect(_ cropRect: CGRect, animated: Bool, duration: TimeInterval = FACropControl.Const.animationDuration) {
        
        let path = self.path(for: cropRect)
        
        if animated {
            
            let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
            animation.fromValue = self.shapeLayer.path
            animation.toValue = path
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            
            self.shapeLayer.add(animation, forKey: animation.keyPath)
        }
        
        self.shapeLayer.path = path
        self.cropRect = cropRect
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.shapeLayer.frame = self.bounds
    }
    
    private func path(for rect: CGRect) -> CGPath {
        let size = self.bounds.size
        
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        
        let cropPath = CGMutablePath()
        cropPath.move(to: rect.origin)
        cropPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        cropPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        cropPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        cropPath.closeSubpath()
        
        path.addPath(cropPath)
        
        return path
    }
}
