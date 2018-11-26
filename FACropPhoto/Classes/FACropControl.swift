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

protocol FACropControlDelegate: NSObjectProtocol {
    func cropControlWillBeginDragging(_ cropControl: FACropControl)
    func cropControlDidEndDragging(_ cropControl: FACropControl)
}

public class FACropControl: UIControl {

    struct Const {
        static var animationDuration: TimeInterval = 0.4
        static var touchAreaWidth: CGFloat = 44
        static var debounceTime: TimeInterval = 1.2
        static var cropInset: CGFloat = 15
    }

    weak var delegate: FACropControlDelegate?
    var cropView: UIView!
    var rotateView: FARotationControl!
    var effectView: UIVisualEffectView!
    
    private(set) var cropFrame: CGRect = .zero
    private(set) var maxCropFrame: CGRect = .zero
    private(set) var panGestureRecognizer: UIPanGestureRecognizer!

    
    // MARK: - Init

    override init(frame: CGRect) {
        
        super.init(frame: frame.extendTo(minSize: CGSize(width: 44, height: 44)))
        
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        self.panGestureRecognizer.maximumNumberOfTouches = 1
        self.panGestureRecognizer.delegate = self
        self.addGestureRecognizer(self.panGestureRecognizer)
        
        let effectView = UIVisualEffectView(frame: self.bounds)
        effectView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        effectView.effect = UIBlurEffect(style: .dark)
        effectView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        let mask = FAMaskView(frame: self.bounds)
        mask.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        mask.backgroundColor = .clear
        self.cropMaskView = mask
        effectView.layer.mask = mask.layer
        self.addSubview(effectView)
        self.effectView = effectView
        
        let cropView = UIView(frame: self.bounds.insetBy(dx: 8, dy: 8))
        cropView.backgroundColor = .clear
        cropView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        cropView.layer.borderColor = UIColor.white.cgColor
        cropView.layer.borderWidth = 1.0
        cropView.isUserInteractionEnabled = false
        self.addSubview(cropView)
        self.cropView = cropView
        
        let rotateControl = FARotationControl(frame: self.bounds.with(width: 60))
        rotateControl.autoresizingMask = [.flexibleWidth,.flexibleTopMargin,.flexibleBottomMargin]
        self.addSubview(rotateControl)
        self.rotateView = rotateControl
        
        let inset = Const.cropInset
        self.maxCropFrame = self.bounds.insetBy(dx: inset, dy: inset)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        self.cropMaskView.frame = self.bounds
        self.cropMaskView.setCropRect(self.cropFrame, animated: false)
        
        let inset = Const.cropInset
        self.maxCropFrame = self.bounds.insetBy(dx: inset, dy: inset)
    }
    
    
    // MARK: - Public
    
    public func splashBlure() {
        self.disableBlur()
        self.debounceSetupBlur()
    }
    
    public func disableBlur() {
        let selector = #selector(self.setupBlur)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
        
        guard self.effectView.effect != nil else { return }
        
        UIView.animate(withDuration: FACropControl.Const.animationDuration, delay: 0, options: [.allowUserInteraction], animations: {
            self.effectView.effect = nil
            
        }) { (_) in }
    }
    
    @objc public func setupBlur() {
        
        guard self.effectView.effect == nil else { return }
        
        UIView.animate(withDuration: FACropControl.Const.animationDuration, delay: 0, options: [.allowUserInteraction], animations: {
            self.effectView.effect = UIBlurEffect(style: .dark)
        }) { (_) in }
    }
    
    public func setCropFrame(_ cropFrame: CGRect, animated: Bool = false) {
        
        var frame = cropFrame
        if !self.maxCropFrame.contains(cropFrame) {
            frame = self.maxCropFrame.intersection(cropFrame)
        }
        self.cropFrame = frame
        
        self.cropView.frame = self.cropFrame
        self.rotateView.frame = self.cropFrame
            .offsetBy(dx: 0, dy: self.cropFrame.height)
            .with(height: 60)
        self.cropMaskView.setCropRect(self.cropFrame, animated: animated)
    }
    
    public func setAspectRatio(_ aspectRatio: AspectRatio, atCenter point: CGPoint? = nil, animated: Bool = false) {
        self.setAspectRatio(aspectRatio.ratio, atCenter: point, animated: animated)
    }
    
    public func setAspectRatio(_ aspectRatio: CGFloat, atCenter point: CGPoint? = nil, animated: Bool = false) {

        let doBlock = {
            let size = self.maxCropFrame.size
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

            self.setCropFrame(cropFrame, animated: animated)
            self.sendActions(for: .valueChanged)
            
            self.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: FACropControl.Const.animationDuration) {
                doBlock()
            }
        } else {
            doBlock()
        }
    }
    
    
    // MARK: - Private
    
    private func debounceSetupBlur() {
        let selector = #selector(self.setupBlur)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
        
        self.perform(selector, with: nil, afterDelay: FACropControl.Const.debounceTime)
    }
    
    
    // MARK: - Override

    
    // MARK: - Actions

    
    // MARK: - Private
    private var cropMaskView: FAMaskView!
    private var directions: UIRectEdge = []
    private var touch: UITouch?
    private var startPoint: CGPoint = .zero
    private var startFrame: CGRect = .zero
    
}

//MARK: - Gesture Recognizer Delegate
extension FACropControl: UIGestureRecognizerDelegate {

    @objc private func panGestureAction(_ sender: UIPanGestureRecognizer) {
        
        switch sender.state {
  
        case .possible: break
            
        case .began:
            let location = sender.location(in: self)
            
            self.startPoint = location
            self.startFrame = self.cropView.frame
            self.disableBlur()
            self.delegate?.cropControlWillBeginDragging(self)
            
        case .changed:
            let translation = sender.translation(in: self)
            let minSide: CGFloat = Const.touchAreaWidth*2.0
            let inset: CGFloat = Const.cropInset

            let frame = self.cropView.frame
            var newFrame = self.startFrame
            if self.directions.contains(.top) {
                let newHeight = newFrame.height - translation.y
                let newY = newFrame.minY + translation.y
                if newHeight >= minSide {
                    if newY >= inset {
                        newFrame.origin.y = newY
                        newFrame.size.height = newHeight
                    } else {
                        newFrame.origin.y = inset
                        newFrame.size.height = newHeight + newY - inset
                    }
                } else {
                    newFrame.origin.y = frame.maxY - minSide
                    newFrame.size.height = minSide
                }
            }
            if self.directions.contains(.left) {
                let newWidth = newFrame.width - translation.x
                let newX = newFrame.minX + translation.x
                if newWidth >= minSide {
                    if newX >= inset {
                        newFrame.origin.x += translation.x
                        newFrame.size.width = newWidth
                    } else {
                        newFrame.origin.x = inset
                        newFrame.size.width = newWidth + newX - inset
                    }
                } else {
                    newFrame.origin.x = frame.maxX - minSide
                    newFrame.size.width = minSide
                }
            }
            if self.directions.contains(.bottom) {
                let newHeight = newFrame.height + translation.y
                if newHeight >= minSide {
                    let maxHeight = self.bounds.height - newFrame.minY - inset
                    newFrame.size.height = min(maxHeight, newHeight)
                } else {
                    newFrame.size.height = minSide
                }
            }
            if self.directions.contains(.right) {
                let newWidth = newFrame.width + translation.x
                if newWidth >= minSide {
                    let maxWidth = self.bounds.width - newFrame.minX - inset
                    newFrame.size.width = min(maxWidth, newWidth)
                } else {
                    newFrame.size.width = minSide
                }
            }
            
            if !self.cropView.frame.equalTo(newFrame) {
                self.setCropFrame(newFrame)
                self.sendActions(for: .valueChanged)
            }
            
        case .ended, .cancelled, .failed:
            self.delegate?.cropControlDidEndDragging(self)
            self.splashBlure()
        }
    }
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        let point = gestureRecognizer.location(in: self)
        let inset = Const.touchAreaWidth/1.5
        let frame = self.cropFrame.insetBy(dx: -inset, dy: -inset)
        let exept = self.cropFrame.insetBy(dx: inset, dy: inset)
        
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

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        return true
    }
}
