//
//  FAGridView.swift
//  FACropPhoto_Example
//
//  Created by Evgeny Bogomolov on 27/11/2018.
//  Copyright © 2018 FaceApp. All rights reserved.
//

import UIKit

public class FAGridView: UIView {
    
    struct Const {
        static var cornerSide: CGFloat = 24
        static var cornerWidth: CGFloat = 4
        static var gridWidth: CGFloat = 1
        static var padding: CGFloat = 3
    }

    let shapeLayer: CAShapeLayer
    
    override public init(frame: CGRect) {
        self.shapeLayer = CAShapeLayer()
        super.init(frame: frame)
        
        self.contentMode = .redraw
        self.layer.addSublayer(self.shapeLayer)
        self.shapeLayer.frame = self.bounds
        self.shapeLayer.strokeColor = UIColor(white: 1.0, alpha: 0.6).cgColor
        self.shapeLayer.lineWidth = Const.gridWidth
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.shapeLayer.frame = self.bounds
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        let size = rect.size
        let corner = Const.cornerSide
        let w = Const.cornerWidth/2
        let p = Const.padding
        context.setLineWidth(Const.cornerWidth)
        context.setStrokeColor(UIColor.white.cgColor)
        context.move(to: CGPoint(x: w+p, y: corner+w+p))
        context.addLine(to: CGPoint(x: w+p, y: w+p))
        context.addLine(to: CGPoint(x: corner+p, y: w+p))
        context.move(to: CGPoint(x: size.width-corner+w-p, y: w+p))
        context.addLine(to: CGPoint(x: size.width-w-p, y: w+p))
        context.addLine(to: CGPoint(x: size.width-w-p, y: corner+p))
        context.move(to: CGPoint(x: size.width-w-p, y: size.height-corner-w-p))
        context.addLine(to: CGPoint(x: size.width-w-p, y: size.height-w-p))
        context.addLine(to: CGPoint(x: size.width-corner-w-p, y: size.height-w-p))
        context.move(to: CGPoint(x: corner+p, y: size.height-w-p))
        context.addLine(to: CGPoint(x: w+p, y: size.height-w-p))
        context.addLine(to: CGPoint(x: w+p, y: size.height-corner-w-p))
        context.strokePath()
    }
    
    public func setFrame(_ frame: CGRect, animated: Bool = false) {
        self.frame = frame
        let path = self.gridPath()

        if animated {
            let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
            animation.fromValue = self.shapeLayer.path
            animation.toValue = path
            animation.duration = FACropControl.Const.animationDuration
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            self.shapeLayer.add(animation, forKey: nil)
            self.shapeLayer.path = path
        } else {
            self.shapeLayer.removeAllAnimations()
            self.shapeLayer.path = path
        }
    }
    
    public func showGrid(_ show: Bool,
                         animated: Bool = false,
                         duration: TimeInterval = FACropControl.Const.animationDuration)
    {
        let opacity: Float = show ? 1.0 : 0.0

        if animated {
            
            let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            animation.fromValue = self.shapeLayer.opacity
            animation.toValue = opacity
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

            self.shapeLayer.opacity = opacity
            self.shapeLayer.add(animation, forKey: nil)
        } else {
            self.shapeLayer.removeAllAnimations()
            self.shapeLayer.opacity = opacity
        }
    }
    
    private func gridPath() -> CGPath {
        let size = self.bounds.size
        let path = CGMutablePath()
        
        let gw = Const.gridWidth
        let width = (size.width - gw*4)/3
        let height = (size.height - gw*4)/3
        var x = gw+width, y = gw+height
        for _ in 0..<2 {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += width
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += height
        }
        
        return path
    }
    
}
