//
//  FAAspectRatioControl.swift
//  FACropPhoto_Example
//
//  Created by Evgeny Bogomolov on 26/11/2018.
//  Copyright © 2018 FaceApp. All rights reserved.
//

import UIKit


public protocol FAAspectRatioControlDelegate: NSObjectProtocol {
    func aspectRatioControl(_ aspectRatioControl: FAAspectRatioControl, cellForIndexPath indexPath: IndexPath) -> UICollectionViewCell
}

public class FAAspectRatioControl: UIControl {
    
    public weak var delegate: FAAspectRatioControlDelegate? {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    private(set) var ratios = AspectRatio.allCases

    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        self.addSubview(collectionView)
        self.collectionView = collectionView
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.collectionView.collectionViewLayout.invalidateLayout()
    }
    
    
    private(set) var collectionView: UICollectionView!
}

extension FAAspectRatioControl: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.delegate == nil ? 0 : self.ratios.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return self.delegate!.aspectRatioControl(self, cellForIndexPath: indexPath)
    }
 
}

extension FAAspectRatioControl: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = self.bounds.height
        return CGSize(width: size, height: size)
    }
}
