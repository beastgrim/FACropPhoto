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
}

public class FARotationScrollView: UIView {
    public var rotationAngle: CGFloat = 0 { didSet { self.rotationAngleDidChange() } }
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
}
