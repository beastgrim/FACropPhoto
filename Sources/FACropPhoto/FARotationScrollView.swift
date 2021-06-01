//
//  FARotationScrollView.swift
//  FACropPhoto_Example
//
//  Created by Evgeny Bogomolov on 20.05.2021.
//  Copyright © 2021 FaceApp. All rights reserved.
//

import UIKit

public extension FARotationScrollView {
    var delegate: UIScrollViewDelegate? {
        get { self.scrollView.delegate }
        set { self.scrollView.delegate = newValue }
    }
    var minimumZoomScale: CGFloat {
        get { self.scrollView.minimumZoomScale }
        set { self.scrollView.minimumZoomScale = newValue }
    }
    var maximumZoomScale: CGFloat {
        get { self.scrollView.maximumZoomScale }
        set { self.scrollView.maximumZoomScale = newValue }
    }
    var zoomScale: CGFloat {
        get { self.scrollView.zoomScale }
        set { self.scrollView.zoomScale = newValue }
    }
    var contentSize: CGSize {
        get { self.scrollView.contentSize }
        set { self.scrollView.contentSize = newValue }
    }
    var isScrollEnabled: Bool {
        get { self.scrollView.isScrollEnabled }
        set { self.scrollView.isScrollEnabled = newValue }
    }
    var contentOffset: CGPoint {
        get { self.scrollView.contentOffset }
        set { self.scrollView.contentOffset = newValue }
    }
    var contentInset: UIEdgeInsets {
        get { self.scrollView.contentInset }
        set { self.scrollView.contentInset = newValue }
    }
    var scrollViewSize: CGSize {
        get { self.scrollView.frame.size }
        set { self.scrollView.frame.size = newValue }
    }
}

private extension FARotationScrollView {
    var realContentSize: CGSize {
        var contentSize = self.contentSize
        contentSize.width /= self.zoomScale
        contentSize.height /= self.zoomScale
        return contentSize
    }
}

public class FARotationScrollView: UIView {
    public var rotationAngle: CGFloat = 0 { didSet { self.rotationAngleDidChange() } }
    public var cropFrame: CGRect = .zero
    
    public let scrollView: UIScrollView = .init()
    public let contentView: UIView = .init()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }
    
    // MARK: - Public
    public func set(frame: CGRect) {
        let angle = self.rotationAngle
        self.rotationAngle = 0
        self.frame = frame
        self.scrollView.frame = self.bounds
        self.rotationAngle = angle
    }
    
    public func updateMinimumZoomScale() {
        let minScale = FACropInfo.minimumScale(cropSize: self.cropFrame.size, fullSize: self.realContentSize, angleInRadians: self.rotationAngle)
        
        if self.minimumZoomScale != minScale {
            self.minimumZoomScale = minScale
        }
    }
    
    public func updateContentInset() {
        var contentInset = self.calculateScrollViewInset()
        let cropFrame = self.cropFrame
        let cropCenter = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        let scrollCenter = self.center
        contentInset.left += (cropCenter.x - scrollCenter.x)
        contentInset.right -= (cropCenter.x - scrollCenter.x)
        contentInset.top += (cropCenter.y - scrollCenter.y)
        contentInset.bottom -= (cropCenter.y - scrollCenter.y)
        
        if self.contentInset != contentInset {
            self.contentInset = contentInset
        }
        // Fix bug scollView when set zero inset
        if self.scrollView.zoomScale == self.scrollView.minimumZoomScale,
            self.scrollView.contentOffset == .zero {
            let inset = self.scrollView.contentInset
            self.scrollView.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
        }
    }
    
    // MARK: - Private
    private func commonInit() {
        self.scrollView.frame = self.bounds
        self.scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.scrollView)
        
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.clipsToBounds = false
        if #available(iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        self.contentView.frame = self.bounds
        self.scrollView.addSubview(self.contentView)
    }
    
    private func rotationAngleDidChange() {
        let transform = CGAffineTransform(rotationAngle: self.rotationAngle)
        if self.transform != transform {
            self.transform = transform
        }
    }
    
    private func calculateScrollViewInset() -> UIEdgeInsets {
        let cropRect = self.cropFrame
        let bounds = self.scrollView.bounds
        let hOffset: CGFloat = (bounds.width - cropRect.width) / 2
        let vOffset: CGFloat = (bounds.height - cropRect.height) / 2
        
        let rotateInsets = FACropInfo.scrollViewInsets(size: cropRect.size, angleInRadians: self.rotationAngle)
        let hInset: CGFloat = rotateInsets.left
        let vInset: CGFloat = rotateInsets.top
        
        let top = vOffset + vInset
        let left = hOffset + hInset
        let bottom = vOffset + vInset
        let right = hOffset + hInset
        
        let insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        return insets
    }
}
