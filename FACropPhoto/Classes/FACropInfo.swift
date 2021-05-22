//
//  FACropInfo.swift
//  FACropPhoto_Example
//
//  Created by Evgeny Bogomolov on 22.05.2021.
//  Copyright © 2021 FaceApp. All rights reserved.
//

import UIKit

public struct FACropInfo {
    public let imageSize: CGSize
    public var cropSize: CGSize
    public var rotationCenter: CGPoint
    public var rotationAngle: CGFloat

    public var isRotated: Bool {
        return self.rotationAngle != 0.0
    }
    public var cropRect: CGRect {
        let croppedRect = CGRect(x: (self.rotationCenter.x - self.cropSize.width/2),
                                 y: (self.rotationCenter.y - self.cropSize.height/2),
                                 width: self.cropSize.width,
                                 height: self.cropSize.height)
        return croppedRect
    }
    
    public init(image: UIImage) {
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        self.imageSize = size
        self.rotationAngle = 0.0
        self.rotationCenter = CGPoint(x: size.width / 2.0, y: size.height / 2)
        self.cropSize = size
    }
    
    public init(size: CGSize) {
        self.imageSize = size
        self.rotationAngle = 0.0
        self.rotationCenter = CGPoint(x: size.width / 2.0, y: size.height / 2)
        self.cropSize = size
    }
    
    public func minimumScale(cropSize: CGSize) -> CGFloat {
        return FACropInfo.minimumScale(cropSize: cropSize, fullSize: self.imageSize, angleInRadians: self.rotationAngle)
    }
    
    public static func minimumScale(cropSize: CGSize, fullSize: CGSize, angleInRadians: CGFloat) -> CGFloat {
        let angle = abs(angleInRadians)
        let cropScaleFill = fullSize.scaleToFill(to: cropSize)
        let cropScaleFit = fullSize.scaleToFit(to: cropSize)
        
        let angleScaleH = self.h_minimumScale(size: cropSize, angle: angle)
        let angleScaleV = self.v_minimumScale(size: cropSize, angle: angle)
        
        let scale1 = angleScaleV * cropScaleFit
        let scale2 = angleScaleH * cropScaleFit
        let scale3 = angleScaleH * cropScaleFill
        let scale4 = angleScaleV * cropScaleFill
        return [scale1, scale2, scale3, scale4].sorted()[2]
    }
    
    public func scrollViewInsets(size: CGSize) -> UIEdgeInsets {
        return FACropInfo.scrollViewInsets(size: size, angleInRadians: self.rotationAngle)
    }
    
    public static func scrollViewInsets(size: CGSize, angleInRadians: CGFloat) -> UIEdgeInsets {
        if angleInRadians == 0.0 { return .zero }
        let angle = abs(angleInRadians)
        let w = size.width / 2
        let h = size.height / 2
        let res1 = w * cos(angle) + h * sin(angle) - w
        let res2 = h * cos(angle) + w * sin(angle) - h
        return UIEdgeInsets(top: -res2, left: -res1, bottom: -res2, right: -res1)
    }
    
    public mutating func reset() {
        self.cropSize = self.imageSize
        self.rotationAngle = 0.0
        self.rotationCenter = CGPoint(x: self.imageSize.width/2.0, y: self.imageSize.height/2)
    }
    
    internal static func distance(p1: CGPoint, p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2.0) + pow(p2.y - p1.y, 2.0))
    }
    
    private static func h_minimumScale(size: CGSize, angle: CGFloat) -> CGFloat {
        let angle = abs(angle)
        let topLeft = self.calculateTrianglePoint(p1: .zero, p2: CGPoint(x: 0, y: size.height), alp1: .pi / 2 - angle, alp2: angle)
        let topRight = self.calculateTrianglePoint(p1: CGPoint(x: size.width, y: 0), p2: .zero, alp1: .pi / 2 - angle, alp2: angle)
        let distance = self.distance(p1: topLeft, p2: topRight)
        
        let scale = distance / size.width
        return scale
    }
    
    private static func v_minimumScale(size: CGSize, angle: CGFloat) -> CGFloat {
        let angle = abs(angle)
        let topLeft = self.calculateTrianglePoint(p1: .zero, p2: CGPoint(x: 0, y: size.height), alp1: .pi / 2 - angle, alp2: angle)
        let bottomLeft = self.calculateTrianglePoint(p1: CGPoint(x: 0, y: size.height), p2: CGPoint(x: size.width, y: size.height), alp1: .pi / 2 - angle, alp2: angle)
        let distance = self.distance(p1: topLeft, p2: bottomLeft)
        let scale = distance / size.height
        return scale
    }
    
    private static func calculateTrianglePoint(p1: CGPoint, p2: CGPoint, alp1: CGFloat, alp2: CGFloat) -> CGPoint {
        let x1 = p1.x; let y1 = p1.y;
        let x2 = p2.x; let y2 = p2.y;
        
        let u = x2-x1; let v = y2-y1;
        let a3 = sqrt(pow(u, 2)+pow(v, 2))
        let alp3 = CGFloat.pi-alp1-alp2
        let a2 = a3*sin(alp2)/sin(alp3)
        let rhs1 = x1*u + y1*v + a2*a3*cos(alp1)
        let rhs2 = y2*u - x2*v + a2*a3*sin(alp1)
        let x3 = (1/pow(a3, 2)) * (u*rhs1 - v*rhs2)
        let y3 = (1/pow(a3, 2)) * (v*rhs1 + u*rhs2)
        return CGPoint(x: x3, y: y3)
    }
    
    private static func calculateTriangleSide(with s1: CGFloat, s2: CGFloat, alp1: CGFloat) -> CGFloat {
        let c2 = pow(s1, 2) + pow(s2, 2) - 2*s1*s2*cos(alp1)
        return sqrt(c2)
    }
}
