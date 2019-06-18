//
//  FARotationControl.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 22/11/2018.
//

import UIKit

open class FARotationControl: UIControl {
    
    public var rotationAngel: CGFloat = 0.0 {
        didSet {
            self.updateDegreesView()
            let degrees = self.rotationAngel * 180 / .pi
            self.textLabel.text = String(format: "%.01fº", degrees)
        }
    }
    public let textLabel: UILabel = .init()
    public let degreesImageView: UIImageView = .init()
    public let notchImageView: UIImageView = .init()

    override init(frame: CGRect) {
    
        super.init(frame: frame)
        
        self.clipsToBounds = true
        self.backgroundColor = .clear
        
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        self.panGestureRecognizer.maximumNumberOfTouches = 1
        self.panGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.panGestureRecognizer)
        
        self.textLabel.textColor = .black
        self.textLabel.font = UIFont.systemFont(ofSize: 15)
        self.textLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.textLabel)
        NSLayoutConstraint.activate([
            self.textLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 2),
            self.textLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ])
        
        self.notchImageView.translatesAutoresizingMaskIntoConstraints = false
        let notchSize = CGSize(width: 9, height: 18)
        UIGraphicsBeginImageContextWithOptions(notchSize, false, UIScreen.main.scale)
        if let context = UIGraphicsGetCurrentContext() {
            context.move(to: CGPoint(x: 0, y: notchSize.height))
            context.addLine(to: CGPoint(x: notchSize.width/2, y: 0))
            context.addLine(to: CGPoint(x: notchSize.width, y: notchSize.height))
            context.closePath()
            context.setFillColor(self.tintColor.cgColor)
            context.fillPath()
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.notchImageView.image = image
        self.addSubview(self.notchImageView)
        NSLayoutConstraint.activate([
            self.notchImageView.topAnchor.constraint(equalTo: self.textLabel.bottomAnchor, constant: 16),
            self.notchImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ])
        
        self.degreesImageView.translatesAutoresizingMaskIntoConstraints = false
        let degreesImage = UIImage(named: "rotate")?.withRenderingMode(.alwaysTemplate)
        self.degreesImageView.image = degreesImage
        self.degreesImageView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        self.degreesImageView.tintColor = UIColor.lightText
        self.addSubview(self.degreesImageView)
        self.degreesViewToBottomConstraint = NSLayoutConstraint(item: self.degreesImageView, attribute: .bottom, relatedBy: .equal, toItem: self.notchImageView, attribute: .top, multiplier: 1.0, constant: -(degreesImage?.size.height ?? 0)/2)
        NSLayoutConstraint.activate([
            self.degreesViewToBottomConstraint,
            self.degreesImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ])
        
        self.updateDegreesView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.updateDegreesView()
    }
    
    // MARK: - Public
    
    public func setRotationAngle(_ angle: CGFloat, animated: Bool = false) {
        let block = {
            self.rotationAngel = angle
        }
        if animated {
            UIView.animate(withDuration: FACropControl.Const.animationDuration, animations: block)
        } else {
            block()
        }
    }
    
    public func setDegreesImage(_ image: UIImage) {
        self.degreesImageView.image = image
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
            
            let maxMove: CGFloat = .pi/4

            self.rotationAngel = min(self.mainRotationAngle + maxMove, max(self.mainRotationAngle - maxMove, newAngle))
            
            self.sendActions(for: .valueChanged)
        case .ended,.cancelled,.failed:
            break
        }
    }
    
    // MARK: - Private
    
    private var startAngle: CGFloat = 0.0
    private var mainRotationAngle: CGFloat = 0.0
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var degreesViewToBottomConstraint: NSLayoutConstraint!
    
    private func updateDegreesView() {
        let tenDegrees: CGFloat = 10 * .pi / 180
        var remindAngle = self.rotationAngel.remainder(dividingBy: tenDegrees)
        if remindAngle > tenDegrees/2 {
            remindAngle = tenDegrees - remindAngle
        }
        let rotate = CGAffineTransform(rotationAngle: remindAngle)
        let transform = CATransform3DMakeAffineTransform(rotate)
        self.degreesImageView.layer.transform = transform
    }
    
}

extension FARotationControl: UIGestureRecognizerDelegate {
    
}
