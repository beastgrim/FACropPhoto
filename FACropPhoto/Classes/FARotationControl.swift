//
//  FARotationControl.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 22/11/2018.
//

import UIKit

open class FARotationControl: UIControl {
    
    public private(set) var rotationAngel: CGFloat = 0.0 {
        didSet {
        }
    }

    override init(frame: CGRect) {
    
        super.init(frame: frame)
        
        self.backgroundColor = .lightText
        
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        self.panGestureRecognizer.maximumNumberOfTouches = 1
        self.panGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.panGestureRecognizer)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Actions
    
    @objc func panGestureAction(_ recognizer: UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: self)
        
        switch recognizer.state {
            
        case .possible:
            break
        case .began:
            self.startAngle = self.rotationAngel
        case .changed:
            
            let intensity = min(1.0, max(-1.0, -translation.x/(self.bounds.width/2)))
            let newAngle = self.startAngle + CGFloat( Double.pi/4 * Double(intensity) )
            
            let maxMove = CGFloat( Double.pi/8 )

            self.rotationAngel = min(self.mainRotationAngle + maxMove, max(self.mainRotationAngle - maxMove, newAngle))
            print("Change angle: \(newAngle)")
            
            self.sendActions(for: .valueChanged)
        case .ended,.cancelled,.failed:
            break
        }
    }
    
    // MARK: - Private
    
    private var startAngle: CGFloat = 0.0
    private var mainRotationAngle: CGFloat = 0.0
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
}

extension FARotationControl: UIGestureRecognizerDelegate {
    
}
