//
//  FAStandartControlsView.swift
//  FACropPhoto_Example
//
//  Created by Evgeny Bogomolov on 26/11/2018.
//  Copyright © 2018 FaceApp. All rights reserved.
//

import UIKit

public class FAStandartControlsView: UIStackView {

    public let aspectRatioButton: UIButton
    
    override init(frame: CGRect) {
        
        let aspectRatioButton = UIButton(type: .custom)
        aspectRatioButton.setTitle("Aspect ratio", for: .normal)
        aspectRatioButton.contentHorizontalAlignment = .center
        self.aspectRatioButton = aspectRatioButton
        
        super.init(frame: frame)
        self.addArrangedSubview(aspectRatioButton)

        self.axis = .horizontal
        
        self.distribution = .fillEqually
        self.alignment = .center
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
