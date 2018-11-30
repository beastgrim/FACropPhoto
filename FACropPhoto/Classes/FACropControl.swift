//
//  FACropControl.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 21/11/2018.
//

import UIKit

public enum AspectRatio: CaseIterable {
    case r1x1
    case r4x5
    case r2x3
    case r9x16
    case r5x4
    case r3x2
    case r16x9
    
    public var ratio: CGFloat {
        switch self {
        case .r1x1:
            return 1.0
        case .r2x3:
            return 2/3
        case .r4x5:
            return 4/5
        case .r9x16:
            return 9/16
        case .r5x4:
            return 5/4
        case .r3x2:
            return 3/2
        case .r16x9:
            return 16/9
        }
    }
    
    public var title: String {
        switch self {
            
        case .r1x1:
            return "1:1"
        case .r2x3:
            return "2:3"
        case .r4x5:
            return "4:5"
        case .r9x16:
            return "9:16"
        case .r5x4:
            return "5:4"
        case .r3x2:
            return "3:2"
        case .r16x9:
            return "16:9"
        }
    }
}

protocol FACropControlDelegate: NSObjectProtocol {
    func cropControlWillBeginDragging(_ cropControl: FACropControl)
    func cropControlDidEndDragging(_ cropControl: FACropControl)
}

public class FACropControl: UIControl {

    public struct Const {
        static public var animationDuration: TimeInterval = 0.4
        static public var touchAreaWidth: CGFloat = 44
        static public var debounceTime: TimeInterval = 1.2
        static public var cropInset: CGFloat = 15
    }

    weak var delegate: FACropControlDelegate?
    var gridView: FAGridView!
    var rotateView: FARotationControl!
    var effectView: UIVisualEffectView!
    var aspectRatio: AspectRatio?
    public var visualEffect: UIVisualEffect = UIBlurEffect(style: UIBlurEffect.Style.dark) {
        didSet { self.effectView.effect = self.visualEffect }
    }
    
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
        effectView.effect = self.visualEffect
        effectView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        let mask = FAMaskView(frame: self.bounds)
        mask.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        mask.backgroundColor = .clear
        self.cropMaskView = mask
        effectView.layer.mask = mask.layer
        self.addSubview(effectView)
        self.effectView = effectView
        
        let cropView = FAGridView(frame: self.bounds.insetBy(dx: 8, dy: 8))
        cropView.backgroundColor = .clear
        cropView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        cropView.layer.borderColor = UIColor.white.cgColor
        cropView.layer.borderWidth = 1.0
        cropView.isUserInteractionEnabled = false
        self.addSubview(cropView)
        self.gridView = cropView
        
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
            self.gridView.showGrid(true, animated: true)
        }) { (_) in }
    }
    
    @objc public func setupBlur() {
        
        guard self.effectView.effect == nil else { return }
        
        UIView.animate(withDuration: FACropControl.Const.animationDuration, delay: 0, options: [.allowUserInteraction], animations: {
            self.effectView.effect = self.visualEffect
            self.gridView.showGrid(false, animated: true)
        }) { (_) in }
    }
    
    public func setCropFrame(_ cropFrame: CGRect, animated: Bool = false) {
        
        var frame = cropFrame
        if !self.maxCropFrame.contains(cropFrame) {
            frame = self.maxCropFrame.intersection(cropFrame)
        }
        self.cropFrame = frame
        
        self.gridView.setFrame(self.cropFrame, animated: animated)
        self.rotateView.frame = self.cropFrame
            .offsetBy(dx: 0, dy: self.cropFrame.height)
            .with(height: 60)
        self.cropMaskView.setCropRect(self.cropFrame, animated: animated)
    }
    
    public func setAspectRatio(_ aspectRatio: AspectRatio, animated: Bool = false) {
        self.setAspectRatio(aspectRatio.ratio, animated: animated)
    }
    
    public func setAspectRatio(_ aspectRatio: CGFloat, animated: Bool = false) {

        let doBlock = {
            let size = self.maxCropFrame.size
            let ratio = aspectRatio
            let height = size.width/ratio
            
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
            self.startFrame = self.gridView.frame
            self.disableBlur()
            self.delegate?.cropControlWillBeginDragging(self)
            
        case .changed:
            let translation = sender.translation(in: self)
            let minSide: CGFloat = Const.touchAreaWidth*2.0
            let inset: CGFloat = Const.cropInset

            let frame = self.gridView.frame
            var newFrame = self.startFrame
            let maxHeight = self.aspectRatio == nil ? self.maxCropFrame.height : self.maxCropFrame.width*self.aspectRatio!.ratio
            let maxWidth = self.aspectRatio == nil ? self.maxCropFrame.width : self.maxCropFrame.width/self.aspectRatio!.ratio
            
            if let ratio = self.aspectRatio?.ratio {
                
                if self.directions.contains(.top),
                    self.directions.contains(.left) {
                    
                    let move = (translation.x + translation.y)/2
                    
                    var point = self.startFrame.origin
                    point.x = max(self.maxCropFrame.minX, min(self.startFrame.maxX-minSide, point.x+move))

                    let width = self.startFrame.maxX-point.x
                    let maxHeight = self.startFrame.maxY-self.maxCropFrame.minY
                    let height = min(maxHeight, width/ratio)

                    newFrame.size.width = height*ratio
                    newFrame.size.height = height
                    point.y = self.startFrame.maxY-height
                    newFrame.origin = point

                } else if self.directions.contains(.top),
                    self.directions.contains(.right) {
                    
                    let move = (-translation.x + translation.y)/2
         
                    var point = CGPoint(x: max(self.startFrame.minX+minSide, min(self.maxCropFrame.maxX, self.startPoint.x-move)),
                                       y: 0)
                    
                    let width = point.x - self.startFrame.minX
                    let maxHeight = self.startFrame.maxY-self.maxCropFrame.minY
                    let height = min(maxHeight, width/ratio)
                    
                    newFrame.size.width = height*ratio
                    newFrame.size.height = height
                    point.x -= width
                    point.y = self.startFrame.maxY-height
                    newFrame.origin = point
                    
                } else if self.directions.contains(.left),
                    self.directions.contains(.bottom) {
                    
                    let move = (translation.x + -translation.y)/2
                    
                    var point = CGPoint(x: max(self.maxCropFrame.minX, min(self.startFrame.maxX-minSide, self.startPoint.x+move)),
                                        y: 0)
                    
                    let width = self.startFrame.maxX-point.x
                    let maxHeight = self.startFrame.maxY-self.maxCropFrame.minY
                    let height = min(maxHeight, width/ratio)
                    
                    newFrame.size.width = height*ratio
                    newFrame.size.height = height
                    point.x = self.startFrame.maxX-width
                    point.y = self.startFrame.minY
                    newFrame.origin = point
                    
                } else if self.directions.contains(.right),
                    self.directions.contains(.bottom) {
                    
                    let move = (-translation.x + -translation.y)/2
                    
                    var point = CGPoint(x: max(self.startFrame.minX+minSide, min(self.maxCropFrame.maxX, self.startPoint.x-move)),
                                        y: 0)
                    
                    let width = point.x - self.startFrame.minX
                    let maxHeight = self.startFrame.maxY-self.maxCropFrame.minY
                    let height = min(maxHeight, width/ratio)
                    
                    newFrame.size.width = height*ratio
                    newFrame.size.height = height
                    point.x = self.startFrame.minX
                    point.y = self.startFrame.minY
                    newFrame.origin = point
                    
                } else if self.directions.contains(.top) {
                    
                    let move = translation.y
                    
                    let minHeight = max(minSide, minSide/ratio)
                    let y = max(self.maxCropFrame.minY, min(self.startFrame.maxY-minHeight, self.startPoint.y+move))
                    let height = self.startFrame.maxY-y
                    let width = min(self.maxCropFrame.width, max(minSide, height*ratio))
                    
                    newFrame.size.width = width
                    newFrame.size.height = width/ratio
                    newFrame.origin.y = y
                    newFrame.origin.x += (self.startFrame.width-width)/2

                } else if self.directions.contains(.left) {

                    let move = translation.x
                    
                    let x = max(self.maxCropFrame.minX, min(self.startFrame.maxX-minSide, self.startPoint.x+move))
                    
                    let width = self.startFrame.maxX-x
                    let maxHeight = self.maxCropFrame.height
                    let height = min(maxHeight, width/ratio)

                    newFrame.size.height = height
                    newFrame.size.width = height*ratio
                    newFrame.origin.x = x
                    newFrame.origin.y += (self.startFrame.height-height)/2
                    
                } else if self.directions.contains(.bottom) {
                    
                    let move = translation.y
                    
                    let maxY = max(self.startFrame.minY+minSide, min(self.maxCropFrame.maxY, self.startPoint.y+move))
                    let maxWidth = self.maxCropFrame.width
                    let height = maxY-self.startFrame.minY
                    let width = min(maxWidth, max(minSide, height*ratio))
                    
                    newFrame.origin.x += (self.startFrame.width-width)/2
                    newFrame.size.width = width
                    newFrame.size.height = width/ratio
                    newFrame.origin.y = maxY-newFrame.height
                    
                } else if self.directions.contains(.right) {
                    
                    let move = translation.x
                    
                    let maxX = max(self.startFrame.minX+minSide, min(self.maxCropFrame.maxX, self.startPoint.x+move))
                    let width = maxX-self.startFrame.minX
                    let maxHeight = self.maxCropFrame.height
                    let height = min(maxHeight, width/ratio)
                    
                    newFrame.origin.y += (self.startFrame.height-height)/2
                    newFrame.size.width = height*ratio
                    newFrame.size.height = height
                    newFrame.origin.x = self.startFrame.minX
                }
                
            } else {
                
                if self.directions.contains(.top) {
                    let newHeight = newFrame.height - translation.y
                    let newY = newFrame.minY + translation.y
                    if newHeight >= minSide {
                        if newY >= inset {
                            newFrame.origin.y = newY
                            newFrame.size.height = min(newHeight, maxHeight)
                        } else {
                            newFrame.origin.y = inset
                            newFrame.size.height = min(newHeight + newY - inset, maxHeight)
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
                            newFrame.size.width = min(newWidth, maxWidth)
                        } else {
                            newFrame.origin.x = inset
                            newFrame.size.width = min(newWidth + newX - inset, maxWidth)
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
            }
            
            if !self.gridView.frame.equalTo(newFrame) {
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
        let inset = Const.touchAreaWidth/2
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
