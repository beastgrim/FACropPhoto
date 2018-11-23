//
//  FACropControl.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 21/11/2018.
//

import UIKit


public enum AspectRatio: CaseIterable {
    case r1x1
    case r2x3
    case r3x5
    case r3x4
    case r4x5
    case r5x7
    case r9x16
    
    var ratio: CGFloat {
        switch self {
        case .r1x1:
            return 1.0
        case .r2x3:
            return 2/3
        case .r3x5:
            return 3/5
        case .r3x4:
            return 3/4
        case .r4x5:
            return 4/5
        case .r5x7:
            return 5/7
        case .r9x16:
            return 9/16
        }
    }
}


public class FACropControl: UIControl {
    
    struct Const {
        static let touchAreaWidth: CGFloat = 44
    }

    
    var cropView: UIView!
    var rotateView: FARotationControl!
    
    var cropFrame: CGRect = .zero {
        didSet {
            self.cropView.frame = self.cropFrame
            self.rotateView.frame = self.cropFrame
                .offsetBy(dx: 0, dy: self.cropFrame.height)
                .with(height: 60)
        }
    }
    
    // MARK: - Init

    override init(frame: CGRect) {
        
        super.init(frame: frame.extendTo(minSize: CGSize(width: 44, height: 44)))
        
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        self.panGestureRecognizer.maximumNumberOfTouches = 1
        self.panGestureRecognizer.delegate = self
        
        let cropView = UIView(frame: self.bounds.insetBy(dx: 8, dy: 8))
        cropView.backgroundColor = .clear
        cropView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        cropView.layer.borderColor = UIColor.white.cgColor
        cropView.layer.borderWidth = 2.0
        cropView.isUserInteractionEnabled = false
        self.addSubview(cropView)
        self.cropView = cropView
        
        let rotateControl = FARotationControl(frame: self.bounds.with(width: 60))
        rotateControl.autoresizingMask = [.flexibleWidth,.flexibleTopMargin,.flexibleBottomMargin]
        self.addSubview(rotateControl)
        self.rotateView = rotateControl
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Public
    
    public func setAspectRatio(_ aspectRatio: AspectRatio, atCenter point: CGPoint? = nil, animated: Bool = false) {
        self.setAspectRatio(aspectRatio.ratio, atCenter: point, animated: animated)
    }
    
    public func setAspectRatio(_ aspectRatio: CGFloat, atCenter point: CGPoint? = nil, animated: Bool = false) {

        let doBlock = {
            let size = self.bounds.size
            let ratio = aspectRatio
            let height = size.width*ratio
            
            var cropFrame: CGRect = .zero
            if height <= size.height {
                cropFrame.size = CGSize(width: size.width, height: height)
            } else {
                let width = size.height/ratio
                cropFrame.size = CGSize(width: width, height: size.height)
            }
            cropFrame.origin = CGPoint(x: self.bounds.midX-cropFrame.width/2,
                                       y: self.bounds.midY-cropFrame.height/2)

            self.cropFrame = cropFrame
            self.sendActions(for: .valueChanged)
            
            self.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.24) {
                doBlock()
            }
        } else {
            doBlock()
        }
    }
    
    
    // MARK: - Override

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        let inset = Const.touchAreaWidth/2.0
        let frame = self.cropView.frame.insetBy(dx: -inset, dy: -inset)
        let exept = self.cropView.frame.insetBy(dx: inset, dy: inset)

        if frame.contains(point), !exept.contains(point) {
            
            var options: UIRectEdge = []
            if point.x > frame.minX, point.x < exept.minX {
                options.insert(.left)
            }
            if point.y > frame.minY, point.y < exept.minY {
                options.insert(.top)
            }
            if point.x > exept.maxX, point.x < frame.maxX {
                options.insert(.right)
            }
            if point.y > exept.maxY, point.y < frame.maxY {
                options.insert(.bottom)
            }
            self.directions = options
            return true
            
        } else if self.rotateView.frame.contains(point) {
            self.directions = []
            return true
        }
        
        self.directions = []
        return false
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superTest = super.hitTest(point, with: event)

        let inset = Const.touchAreaWidth/2.0
        let frame = self.cropView.frame.insetBy(dx: -inset, dy: -inset)

        if frame.contains(point), superTest != nil {
            return self
        }
        return superTest
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard self.touch == nil, let touch = touches.first else { return }
        
        self.touch = touch
        self.startPoint = touch.location(in: self)
        self.startFrame = self.cropView.frame
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = self.touch, touches.contains(touch) else { return }
        
        let newLocation = touch.location(in: self)
        let minSide: CGFloat = Const.touchAreaWidth*2.0

        let translation = CGPoint(x: newLocation.x-self.startPoint.x,
                                  y: newLocation.y-self.startPoint.y)
        let frame = self.cropView.frame
        var newFrame = self.startFrame
        if self.directions.contains(.top) {
            let newHeight = newFrame.height - translation.y
            if newHeight >= minSide {
                newFrame.origin.y += translation.y
                newFrame.size.height = newHeight
            } else {
                newFrame.origin.y = frame.maxY - minSide
                newFrame.size.height = minSide
            }
        }
        if self.directions.contains(.left) {
            let newWidth = newFrame.width - translation.x
            if newWidth >= minSide {
                newFrame.origin.x += translation.x
                newFrame.size.width = newWidth
            } else {
                newFrame.origin.x = frame.maxX - minSide
                newFrame.size.width = minSide
            }
        }
        if self.directions.contains(.bottom) {
            let newHeight = newFrame.height + translation.y
            if newHeight >= minSide {
                newFrame.size.height = newHeight
            } else {
                newFrame.size.height = minSide
            }
        }
        if self.directions.contains(.right) {
            let newWidth = newFrame.width + translation.x
            if newWidth >= minSide {
                newFrame.size.width += translation.x
            } else {
                newFrame.size.width = minSide
            }
        }
   
        if !self.cropView.frame.equalTo(newFrame) {
            self.cropFrame = newFrame
            self.sendActions(for: .valueChanged)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touch = nil
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touch = nil
    }
    
    
    // MARK: _ Actions
    
    @objc private func panGestureAction(_ sender: UIPanGestureRecognizer) {
        
    }
    
    // MARK: - Private
    private var directions: UIRectEdge = []
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var touch: UITouch?
    private var startPoint: CGPoint = .zero
    private var startFrame: CGRect = .zero
    
}

extension FACropControl: UIGestureRecognizerDelegate {
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
}
