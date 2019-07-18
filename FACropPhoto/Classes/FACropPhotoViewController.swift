//
//  FACropPhotoViewController.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 21/11/2018.
//

import UIKit
import os.log

public enum FACropAspectRatio {
    case original
    case industry(_ ratio: AspectRatio)
}

public struct FACropPhotoOptions {
    public var showControls: Bool
    public var controlsHeight: CGFloat
    
    public init() {
        self.showControls = false
        self.controlsHeight = 0.0
    }
}

public struct CropInfo {
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
        let size = CGSize(width: image.size.width*image.scale, height: image.size.height*image.scale)
        self.imageSize = size
        self.rotationAngle = 0.0
        self.rotationCenter = CGPoint(x: size.width/2.0, y: size.height/2)
        self.cropSize = size
    }

    public mutating func setRotationCenter(_ center: CGPoint) {
        self.rotationCenter = center
    }
    
    public func minimumScale() -> CGFloat {
        guard self.isRotated else { return 1.0 }
        let angle = abs(self.rotationAngle)
        let size = self.imageSize
        let minSide = min(size.width, size.height)
        let maxSide = max(size.width, size.height)
        
        let top = self.calculateTrianglePoint(p1: .zero, p2: CGPoint(x: maxSide, y: 0), alp1: .pi/2+angle, alp2: -angle)
        let left = self.calculateTrianglePoint(p1: .zero, p2: CGPoint(x: 0, y: minSide), alp1: angle, alp2: .pi/2-angle)
        let distance = self.distance(p1: top, p2: left)
        
        let scale = distance/minSide
        return scale
    }
    
    public func scrollViewInsets(size: CGSize) -> UIEdgeInsets {
        guard self.isRotated else { return .zero }
        let angle = abs(self.rotationAngle)
        let w = size.width/2
        let h = size.height/2
        let res1 = w * cos(angle) + h * sin(angle) - w
        let res2 = h * cos(angle) + w * sin(angle) - h

        return UIEdgeInsets(top: -res2, left: -res1, bottom: -res2, right: -res1)
    }
    
    public mutating func reset() {
        self.cropSize = self.imageSize
        self.rotationAngle = 0.0
        self.rotationCenter = CGPoint(x: self.imageSize.width/2.0, y: self.imageSize.height/2)
    }
    
    internal func distance(p1: CGPoint, p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x-p1.x, 2.0) + pow(p2.y-p1.y, 2.0))
    }
    
    private func calculateTrianglePoint(p1: CGPoint, p2: CGPoint, alp1: CGFloat, alp2: CGFloat) -> CGPoint {
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
    
    private func calculateTriangleSide(with s1: CGFloat, s2: CGFloat, alp1: CGFloat) -> CGFloat {
        let c2 = pow(s1, 2) + pow(s2, 2) - 2*s1*s2*cos(alp1)
        return sqrt(c2)
    }

}

public protocol FACropPhotoViewControllerDelegate: NSObjectProtocol {
    func cropPhotoViewController(_ cropPhotoViewController: FACropPhotoViewController, titleFor aspectRatio: FACropAspectRatio) -> String
    func cropPhotoViewController(_ cropPhotoViewController: FACropPhotoViewController, didSetAspectRatio aspectRatio: FACropAspectRatio?)
}

public class FACropPhotoViewController: UIViewController {
    
    struct ViewState {
        var scrollViewZoom: CGFloat
        var scrollViewOffset: CGPoint
        var scrollViewInset: UIEdgeInsets
        var scrollViewSize: CGSize
        var rotationAngle: CGFloat
        var cropControlFrame: CGRect
        var aspectRatio: AspectRatio?
        
        static let initial = ViewState(scrollViewZoom: 1.0,
                                       scrollViewOffset: .zero,
                                       scrollViewInset: .zero,
                                       scrollViewSize: .zero,
                                       rotationAngle: 0.0,
                                       cropControlFrame: .zero,
                                       aspectRatio: nil)
    }
    
    struct UpdateAction: OptionSet {
        public let rawValue: Int

        static let offset = UpdateAction(rawValue: 1<<0)
        static let zoom =   UpdateAction(rawValue: 1<<1)
        static let crop =   UpdateAction(rawValue: 1<<2)
        static let size =   UpdateAction(rawValue: 1<<3)
        static let rotate = UpdateAction(rawValue: 1<<4)
        static let inset =  UpdateAction(rawValue: 1<<5)
        static let ratio =  UpdateAction(rawValue: 1<<6)
        static let position = UpdateAction(rawValue: 1<<7)

        static let all: UpdateAction = [.offset, .zoom, .crop, .size, .rotate, .inset, .ratio, .position]
    }
    
    struct Const {
        static var controlsHeight: CGFloat = 44.0
    }
    public private(set) var initialCropInfo: CropInfo?
    public var image: UIImage {
        didSet {
            let size = oldValue.size
            let scale = oldValue.scale
            let newValue = self.image
            
            if self.isViewLoaded {
                self.imageView.image = newValue
                let newSize = self.imageView.sizeThatFits(.zero)
                
                if (size != newValue.size || scale != newValue.scale) {
                    
                    self.scrollView.zoomScale = 1.0
                    self.imageContainerView.frame.size = newSize
                    self.scrollView.contentSize = newSize
                    self.setupScrollView()
                }
            }
        }
    }
    public let options: FACropPhotoOptions
    public weak var delegate: FACropPhotoViewControllerDelegate?
    public private(set) var cropAspectRatio: FACropAspectRatio? {
        didSet {
            self.delegate?.cropPhotoViewController(self, didSetAspectRatio: self.cropAspectRatio)
        }
    }
    public private(set) var standartControlsView: FAStandartControlsView?
    public private(set) var cropControl: FACropControl!
    public var rotateControl: FARotationControl! {
        return self.cropControl?.rotateView
    }
    public private(set) var cropInfo: CropInfo
    private(set) var viewState: ViewState
    private(set) var contentView: UIView!
    private(set) var scrollContentView: UIView!
    private(set) var controlsContentView: UIView!
    private(set) var imageContainerView: UIView!
    private(set) var scrollView: UIScrollView!
    private(set) var imageView: UIImageView!
    private(set) var aspectRatioControl: FAAspectRatioControl!

    public var isCropped: Bool {
        var isCropped = false
        if self.cropInfo.isRotated {
            isCropped = true
        }
        let size = CGSize(width: round(self.cropInfo.cropSize.width),
                          height: round(self.cropInfo.cropSize.height))
        if self.cropInfo.imageSize != size {
            isCropped = true
        }
        
        return isCropped
    }
    
    
    // MARK: - Life Cycle
    
    public init(image: UIImage, options: FACropPhotoOptions = FACropPhotoOptions()) {
        self.image = image
        self.options = options
        self.viewState = ViewState.initial
        self.cropInfo = CropInfo(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.observations.forEach({ $0.invalidate() })
    }
    
    
    // MARK: - Override
    
    override public func loadView() {
        super.loadView()
        
        self.view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        self.view.frame = self.view.frame.extendTo(minSize: CGSize(width: 240, height: 320))
        let bounds = self.view.bounds
        self.viewSize = self.view.bounds.size
        
        let controlsHeight: CGFloat = self.options.controlsHeight
        
        let contentView = UIView(frame: bounds.croppedBy(side: controlsHeight, options: .bottom))
        contentView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        contentView.clipsToBounds = true
        self.view.addSubview(contentView)
        self.contentView = contentView
        
        let controlsView = UIView(frame: bounds.with(height: controlsHeight, options: .bottom))
        controlsView.autoresizingMask = [.flexibleWidth,.flexibleTopMargin]
        controlsView.isHidden = !self.options.showControls
        self.view.addSubview(controlsView)
        self.controlsContentView = controlsView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false

        let scrollContentView = UIView(frame: self.contentView.bounds)
        scrollContentView.autoresizingMask = [.flexibleWidth,. flexibleHeight]
        let scrollView = UIScrollView(frame: scrollContentView.bounds)
        scrollView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.observations += [
            scrollView.observe(\.contentInset, options: [.initial,.new]) { [unowned self] (scrollView, _) in
            self.viewState.scrollViewInset = scrollView.contentInset
        }]
        scrollContentView.addSubview(scrollView)
        self.contentView.addSubview(scrollContentView)
        self.scrollContentView = scrollContentView
        self.scrollView = scrollView
        
        let imageView = UIImageView(image: self.image)
        imageView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        imageView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        scrollView.contentSize = imageView.sizeThatFits(.zero)
        scrollView.maximumZoomScale = 10.0
        let imageContainer = UIView(frame: imageView.bounds)
        imageContainer.addSubview(imageView)
        self.imageView = imageView
        scrollView.addSubview(imageContainer)
        self.imageContainerView = imageContainer

        let cropControl = FACropControl(frame: self.contentView.bounds)
        cropControl.delegate = self
        cropControl.isUserInteractionEnabled = false
        cropControl.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        cropControl.addTarget(self, action: #selector(cropControlDidChangeValue(_:)), for: .valueChanged)
        cropControl.rotateView.addTarget(self, action: #selector(cropControlDidChangeAngle(_:)), for: .valueChanged)
        self.contentView.addSubview(cropControl)
        self.cropControl = cropControl
        
        if self.options.showControls {
            let controls = FAStandartControlsView(frame: self.controlsContentView.bounds)
            controls.autoresizingMask = [.flexibleWidth,.flexibleHeight]
            controls.aspectRatioButton.addTarget(self, action: #selector(shooseAspectRatioAction(_:)), for: .touchUpInside)
            self.controlsContentView.addSubview(controls)
            self.standartControlsView = controls
            
            /*
            let aspectRatioControl = FAAspectRatioControl(frame: self.controlsContentView.bounds)
            aspectRatioControl.autoresizingMask = [.flexibleWidth,.flexibleHeight]
            aspectRatioControl.delegate = self
            aspectRatioControl.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
            self.controlsContentView.addSubview(aspectRatioControl)
            self.aspectRatioControl = aspectRatioControl
             */
        }
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self.cropControl, action: #selector(FACropControl.panGestureAction(_:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.delegate = self.cropControl
        self.contentView.addGestureRecognizer(scrollView.panGestureRecognizer)
        if let pinchGestureRecognizer = scrollView.pinchGestureRecognizer {
            self.contentView.addGestureRecognizer(pinchGestureRecognizer)
        }
        self.contentView.addGestureRecognizer(panGestureRecognizer)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.isFirstAppear {
            self.swipeToBackGestureIsOn = self.navigationController?.interactivePopGestureRecognizer?.isEnabled ?? false
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        if self.isFirstAppear {
            self.isFirstAppear = false
        }
        self.updateUI()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = self.swipeToBackGestureIsOn
        self.disableAllAnimations()
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.viewSize != self.view.bounds.size {
            self.viewSize = self.view.bounds.size
            
            self.layoutSubviews()
            self.viewState.scrollViewSize = self.scrollView.bounds.size
            
            if self.isFirstAppear {
                self.setupScrollView()
                self.scrollViewDidZoom(self.scrollView)
            } else {
                self.initialCropInfo = self.cropInfo
                self.setupScrollView()
                DispatchQueue.main.async {
                    self.setupScrollView()
                }
            }
        }
    }
    
    public override func viewSafeAreaInsetsDidChange() {
        if #available(iOS 11.0, *) {
            super.viewSafeAreaInsetsDidChange()
            
            self.layoutSubviews()
        }
    }
    
    // MARK: - Public
    
    @objc public func resetCropping(_ sender: Any?) {
        self.resetCropping(animated: true)
    }
    
    public func resetCropping(animated: Bool = false) {
        
        let doBlock = {
            self.cropControl?.rotateView.rotationAngel = 0.0
            self.initialCropInfo = nil
            self.cropAspectRatio = nil
            self.viewState.aspectRatio = nil
            self.viewState.rotationAngle = 0.0
            self.cropInfo.reset()
            self.setupScrollView(animated: animated)
            self.view.layoutIfNeeded()
        }

        self.scrollView?.isScrollEnabled = false
        if animated {
            UIView.animate(withDuration: FACropControl.Const.animationDuration, animations: doBlock, completion:{ (_) in
                self.cropInfo.reset()
                self.scrollView?.isScrollEnabled = true
            })
        } else {
            doBlock()
            self.scrollView?.isScrollEnabled = true
        }
    }
    
    public func setCropAspecRatio(_ aspectRatio: FACropAspectRatio, animated: Bool = false) {
        self.cropAspectRatio = aspectRatio
        var ratioValue: CGFloat
        
        switch aspectRatio {
        case .original:
            ratioValue = self.image.size.width/self.image.size.height
            self.viewState.aspectRatio = nil
        case .industry(let ratio):
            ratioValue = ratio.ratio
            self.viewState.aspectRatio = ratio
        }
        self.cropControl?.setAspectRatio(ratioValue, animated: animated)
        self.alignCropToCenter(animated: animated)
        self.updateUI(animated: false, options: .ratio)
    }
    
    public func alignCropToCenter(animated: Bool = false) {
        
        guard self.isViewLoaded else { return }
        
        let selector = #selector(self.alignCropAction)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
        
        let doBlock = {
            let cropInfo = self.cropInfo
            let cropMaxSize = self.cropControl.maxCropFrame.size
            let scaleChange = self.cropControl.cropFrame.size.scaleToFit(to: cropMaxSize)
            let newCropSize = CGSize(width: self.cropControl.cropFrame.size.width * scaleChange,
                                     height: self.cropControl.cropFrame.size.height * scaleChange)

            do { // Calculate crop control frame
                let cropFrame = self.calculateMaxCropFrame(size: newCropSize)
                self.viewState.cropControlFrame = cropFrame
            }
 
            do { // Calculate scroll view zoom
                let minScale = self.imageView.bounds.size.scaleToFill(to: newCropSize) * self.cropInfo.minimumScale()
                let maxScale = self.scrollView.maximumZoomScale
                let newScale = min(maxScale, max(minScale, self.viewState.scrollViewZoom*scaleChange))
                self.userZoom = newScale
                self.viewState.scrollViewZoom = newScale
                
                self.updateUI(animated: animated, options: [.zoom,.inset])
                self.cropInfo = cropInfo // Restore crop info after update zoom
            }
            do { // Caclulating scroll offset
                let scale = self.viewState.scrollViewZoom
                let imageScale = self.image.scale
                let rotationCenter = self.cropInfo.rotationCenter
                let imageCropSize = self.cropInfo.cropSize.scale(1.0/imageScale)

                let cropFrame = self.viewState.cropControlFrame
                
                let insetX = (self.cropControl.bounds.width - cropFrame.width)/2
                let insetY = (self.cropControl.bounds.height - cropFrame.height)/2

                let cropOrigin = CGPoint(x: rotationCenter.x/imageScale - imageCropSize.width/2,
                                         y: rotationCenter.y/imageScale - imageCropSize.height/2)
                let contentOffset = CGPoint(x: cropOrigin.x*scale - insetX,
                                            y: cropOrigin.y*scale - insetY)
                self.viewState.scrollViewOffset = contentOffset
            }
   
            self.updateUI(animated: animated)
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: FACropControl.Const.animationDuration, animations: doBlock, completion: { _ in
                self.updateUI(animated: false)
            })
        } else {
            doBlock()
        }
    }
    
    public func createCroppedImage() -> UIImage {
        return self.createCroppedImage(from: self.image, crop: self.cropInfo)!
    }
    
    public func setInitialCrop(_ cropInfo: CropInfo) {
        self.initialCropInfo = cropInfo
        self.cropInfo = cropInfo

        if self.isViewLoaded {
            self.disableAllAnimations()
            self.cropAspectRatio = nil
            self.viewState.aspectRatio = nil
            self.viewState.scrollViewZoom = 1.0
            self.viewState.rotationAngle = self.initialCropInfo?.rotationAngle ?? 0.0
            self.setupScrollView()
        }
    }
    
    // MARK: - Actions

    @objc private func cropControlDidChangeValue(_ cropControl: FACropControl) {
        self.viewState.cropControlFrame = cropControl.cropFrame
        let zoomScale = self.scrollView.zoomScale
        let cropSize = self.cropControl.cropFrame.size.scale(self.image.scale/zoomScale)
        self.cropInfo.cropSize = cropSize
        
        let cropFrame = cropControl.cropFrame
        let cropCenter = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        let rotationCenter = self.cropControl.convert(cropCenter, to: self.imageView).scale(self.image.scale)
        self.cropInfo.setRotationCenter(rotationCenter)

        self.updateUI(animated: false, options: [.crop, .inset, .zoom])
    }
    
    @objc private func cropControlDidChangeAngle(_ angleControl: FARotationControl) {
        self.viewState.rotationAngle = angleControl.rotationAngel
        self.cropInfo.rotationAngle = angleControl.rotationAngel
        self.updateUI()
    }
    
    private func disableAlign() {
        let selector = #selector(self.alignCropAction)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
        self.cropControl.disableBlur()
    }
    
    private func debounceAlign() {
        self.disableAlign()
        let selector = #selector(self.alignCropAction)
        self.perform(selector, with: nil, afterDelay: FACropControl.Const.debounceTime)
    }
    
    @objc private func alignCropAction() {
        self.alignCropToCenter(animated: true)
        self.cropControl.setupBlur()
    }
    
    @objc public func shooseAspectRatioAction(_ sender: Any?) {
        
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        let title = self.delegate?.cropPhotoViewController(self, titleFor: .original) ??
            NSLocalizedString("Original", comment: "")
        
        sheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] (action) in

            guard let self = self else { return }
            
            let ratio = self.image.size.width/self.image.size.height
            let aspectRatio = AspectRatio.custom(ratio: ratio)
            self.viewState.aspectRatio = aspectRatio
            let uiRatio = FACropAspectRatio.industry(aspectRatio)
            self.setCropAspecRatio(uiRatio, animated: true)
        }))

        AspectRatio.allCases.forEach { (ratio) in
            let uiRatio = FACropAspectRatio.industry(ratio)
            let title = self.delegate?.cropPhotoViewController(self, titleFor: uiRatio) ?? ratio.title

            sheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] (action) in
                
                self?.viewState.aspectRatio = ratio
                self?.setCropAspecRatio(uiRatio, animated: true)
            }))
        }
        
        self.present(sheet, animated: true, completion: nil)
    }
    
    @objc public func cancelAspectRatioAction(_ sender: Any?) {
        self.viewState.aspectRatio = nil
        self.updateUI(animated: true, options: .ratio)
    }
    
    
    // MARK: - Private
    private var observations: [NSKeyValueObservation] = []
    private var isFirstAppear = true
    private var swipeToBackGestureIsOn: Bool = false
    private var userZoom: CGFloat = 1.0
    private var viewSize: CGSize = .zero
    private var isUserInteraction: Bool = false
    
    private func setupScrollView(animated: Bool = false) {
        
        let cropMaxSize = self.cropControl.maxCropFrame.size

        self.scrollView.minimumZoomScale = 0.0
        self.scrollContentView.transform = .identity
        self.scrollContentView.frame = self.contentView.bounds

        if let initialCrop = self.initialCropInfo {
            let cropSize = initialCrop.cropSize.scale(1.0/self.image.scale)

            self.cropInfo = initialCrop

            let initialScale = cropSize.scaleToFit(to: cropMaxSize)
            self.userZoom = initialScale
            self.viewState.scrollViewZoom = initialScale
            self.updateUI(animated: animated, options: [.zoom])
            
            let size = cropSize.scale(initialScale)
            
            let cropFrame = self.calculateMaxCropFrame(size: size)
            self.viewState.cropControlFrame = cropFrame
            self.cropControl.setCropFrame(cropFrame)

            self.cropInfo = initialCrop
            self.alignCropToCenter(animated: animated)

        } else {
            let imageSize = self.image.size
            let fitScale = imageSize.scaleToFit(to: cropMaxSize)
            let cropFrame = self.calculateMaxCropFrame(size: imageSize)
            
            self.userZoom = fitScale
            self.viewState.scrollViewZoom = fitScale
            self.viewState.scrollViewOffset = .zero
            self.viewState.cropControlFrame = cropFrame
            self.viewState.rotationAngle = 0.0
        }
        
        self.rotateControl.setRotationAngle(self.viewState.rotationAngle, animated: animated)
        self.updateUI(animated: animated)
        self.cropControl.setupBlur()
    }
    
    private func calculateScrollViewInset() -> UIEdgeInsets {
        let cropRect = self.cropControl.cropFrame
        let hOffset: CGFloat = (self.cropControl.bounds.width - cropRect.width)/2
        let vOffset: CGFloat = (self.cropControl.bounds.height - cropRect.height)/2

        let rotateInsets = self.cropInfo.scrollViewInsets(size: cropRect.size)
        let hInset: CGFloat = rotateInsets.left
        let vInset: CGFloat = rotateInsets.top

        let top = vOffset + vInset
        let left = hOffset + hInset
        let bottom = vOffset + vInset
        let right = hOffset + hInset
        
        let insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        return insets
    }
    
    private func updateUI(animated: Bool = false, options: UpdateAction? = nil) {
        let action = options ?? .all
        
        if action.contains(.size) {
            if self.scrollView.frame.size != self.viewState.scrollViewSize {
                self.scrollView.frame.size = self.viewState.scrollViewSize
            }
        }
        
        if action.contains(.zoom) {
            let size = self.viewState.cropControlFrame.size
            var minScale = self.imageView.bounds.size.scaleToFill(to: size)
            minScale *= self.cropInfo.minimumScale()

            if self.scrollView.minimumZoomScale != minScale {
                self.scrollView.minimumZoomScale = minScale
            }
            if self.viewState.scrollViewZoom < minScale {
                self.viewState.scrollViewZoom = minScale
            }
            
            let zoom = max(minScale, min(self.viewState.scrollViewZoom, self.userZoom))
            if self.scrollView.zoomScale != zoom {
                self.scrollView.zoomScale = zoom
            }
        }

        if action.contains(.offset) {
            let contentOffset = self.viewState.scrollViewOffset
            if self.scrollView.contentOffset != contentOffset {
                self.scrollView.contentOffset = contentOffset
            }
        }

        if action.contains(.rotate) {
            let view = self.scrollContentView!
            let transform = CGAffineTransform(rotationAngle: self.viewState.rotationAngle)
            if view.transform != transform {
                view.transform = transform
            }
        }

        if action.contains(.crop) {
            if !self.cropControl.cropFrame.equalTo(self.viewState.cropControlFrame) {
                self.cropControl.setCropFrame(self.viewState.cropControlFrame, animated: animated)
            }
        }
        
        if action.contains(.position) {
            let cropFrame = self.cropControl.cropFrame
            self.scrollContentView.center = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        }

        if action.contains(.inset) {
            var contentInset = self.calculateScrollViewInset()
            let cropFrame = self.cropControl.cropFrame
            let cropCenter = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
            let scrollCenter = self.scrollContentView.center
            contentInset.left += (cropCenter.x - scrollCenter.x)
            contentInset.right -= (cropCenter.x - scrollCenter.x)
            contentInset.top += (cropCenter.y - scrollCenter.y)
            contentInset.bottom -= (cropCenter.y - scrollCenter.y)
            if self.scrollView.contentInset != contentInset {
                self.scrollView.contentInset = contentInset
            }
        }
        
        if action.contains(.ratio) {
            let aspectRatio = self.viewState.aspectRatio
            self.cropControl.aspectRatio = aspectRatio

            let isSelected = self.viewState.aspectRatio != nil
            if self.standartControlsView?.aspectRatioButton.isSelected != isSelected {
                self.standartControlsView?.aspectRatioButton.isSelected = isSelected
            }
        }
        
        // Fix bug scollView when set zero inset
        if self.scrollView.zoomScale == self.scrollView.minimumZoomScale,
            self.scrollView.contentOffset == .zero {
            let inset = self.scrollView.contentInset
            self.scrollView.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
        }
    }
    
    private func disableAllAnimations() {
        let selector = #selector(self.alignCropAction)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
    }
    
    private func calculateTrianglePoint(with p1: CGPoint, p2: CGPoint, alp1: CGFloat, alp2: CGFloat) -> CGPoint {
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
    
    private func calculateTriangleSide(with s1: CGFloat, s2: CGFloat, alp1: CGFloat) -> CGFloat {
        let c2 = pow(s1, 2) + pow(s2, 2) - 2*s1*s2*cos(alp1)
        return sqrt(c2)
    }
    
    private func createCroppedImage(from rawImage: UIImage, crop: CropInfo) -> UIImage? {
        guard let cgImage = rawImage.cgImage else {
            return nil
        }
        
        let bitmapSize = CGSize(width: cgImage.width, height: cgImage.height)
        var result: CIImage = CIImage(cgImage: cgImage)
        
        do { // 1. Make rotation over rotation center
            if crop.isRotated {
                let size = bitmapSize
                
                let rotationPoint = crop.rotationCenter
                let offset = CGPoint(x: rotationPoint.x, y: size.height-rotationPoint.y)
                
                let moveToZero = CGAffineTransform(translationX: -offset.x, y: -offset.y)
                let rotation = CGAffineTransform(rotationAngle: CGFloat(-crop.rotationAngle))
                let moveToPoint = CGAffineTransform(translationX: offset.x, y: offset.y)
                let transform = moveToZero.concatenating(rotation).concatenating(moveToPoint)
                
                let rotateExtent = CGRect(origin: .zero, size: bitmapSize)
                result = result.transformed(by: transform).cropped(to: rotateExtent)
            }
        }
        do { // 2. Make backgorund color
            if crop.isRotated {
                let bgColor = UIColor.black
                let extent = CGRect(origin: .zero, size: bitmapSize)
                let bgImage = CIImage(color: CIColor(color: bgColor)).cropped(to: extent)
                result = result.composited(over: bgImage)
            }
        }
        do { // 3. Crop image
            do {
                let cropSize = crop.cropSize
                let center = crop.rotationCenter

                let cropRect = CGRect(x: center.x-cropSize.width/2, y: center.y-cropSize.height/2,
                                      width: cropSize.width, height: cropSize.height)
                let move = CGAffineTransform(translationX: -cropRect.minX, y: -(bitmapSize.height - cropRect.maxY))
                let cropExtent = CGRect(origin: .zero, size: cropRect.size)
                result = result.transformed(by: move).cropped(to: cropExtent)
            }
        }
        
        guard let image = CIContext().createCGImage(result, from: result.extent) else {
            return nil
        }
        
        let output = UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up)
        return output
    }
    
    private func calculateMaxCropFrame(size: CGSize) -> CGRect {
        let cropCenter = CGPoint(x: self.cropControl.maxCropFrame.midX,
                                 y: self.cropControl.maxCropFrame.midY)
        let cropMaxSize = self.cropControl.maxCropFrame.size
        let scaleChange = size.scaleToFit(to: cropMaxSize)
        let newCropSize = size.scale(scaleChange)
        
        let result = CGRect(origin: CGPoint(x: cropCenter.x - newCropSize.width/2,
                                            y: cropCenter.y - newCropSize.height/2),
                            size: newCropSize)
        return result
    }
    
    private func layoutSubviews() {
        
        var insets: UIEdgeInsets = .zero
        if #available(iOS 11.0, *) {
            insets = self.view.safeAreaInsets
        }
        self.controlsContentView.frame = self.view.bounds
            .with(height: Const.controlsHeight, options: .bottom)
            .offsetBy(dx: 0, dy: -insets.bottom)
        self.contentView.frame = self.view.bounds
            .croppedBy(y: insets.top)
            .croppedBy(side: insets.bottom+self.options.controlsHeight, options: .bottom)
        self.scrollContentView.transform = .identity
        self.scrollContentView.frame = self.contentView.bounds
        self.scrollView.frame = self.contentView.bounds
        self.cropControl.frame = self.scrollView.frame
        self.viewState.scrollViewSize = self.scrollView.bounds.size
    }
}


//MARK: - Scroll View Delegate
extension FACropPhotoViewController: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageContainerView
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.isUserInteraction = true
        self.disableAlign()
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        self.isUserInteraction = true
        self.disableAlign()
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.debounceAlign()
        if !decelerate {
            self.isUserInteraction = false
        }
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        self.debounceAlign()
        self.userZoom = scrollView.zoomScale
        self.isUserInteraction = false
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.viewState.scrollViewOffset = scrollView.contentOffset
        let cropFrame = self.cropControl.cropFrame
        let cropCenter = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        let rotationCenter = self.cropControl.convert(cropCenter, to: self.imageView).scale(self.image.scale)
        if self.isUserInteraction {
            self.cropInfo.setRotationCenter(rotationCenter)
        }
        self.updateUI(animated: false, options: [.inset])
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let zoomScale = scrollView.zoomScale
        let cropSize = self.cropControl.cropFrame.size.scale(self.image.scale/zoomScale)
        self.viewState.scrollViewZoom = zoomScale
        
        if self.isUserInteraction {
            self.cropInfo.cropSize = cropSize
        }
        self.updateUI(animated: false, options: [.inset])
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.isUserInteraction = false
    }
}

//MARK: - Crop Control Delegate
extension FACropPhotoViewController: FACropControlDelegate {

    func cropControlWillBeginDragging(_ cropControl: FACropControl) {
        self.disableAlign()
    }
    
    func cropControlDidEndDragging(_ cropControl: FACropControl) {
        self.debounceAlign()
    }
}

//MARK: - Aspect Ratio Control Delegate
extension FACropPhotoViewController: FAAspectRatioControlDelegate {
    
    public func aspectRatioControl(_ aspectRatioControl: FAAspectRatioControl, cellForIndexPath indexPath: IndexPath) -> UICollectionViewCell {

        let cell = aspectRatioControl.collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        if cell.tag == 0 {
            cell.tag += 1
            let imageView = UIImageView(frame: cell.bounds)
            imageView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
            imageView.tag = 1
            cell.contentView.addSubview(imageView)
            cell.backgroundColor = .clear
        }
        let imageView = cell.contentView.viewWithTag(1) as! UIImageView
        let ratio = aspectRatioControl.ratios[indexPath.row]
        imageView.image = UIImage.generateIcon(size: cell.bounds.size, aspectRatio: ratio)

        return cell
    }
}

