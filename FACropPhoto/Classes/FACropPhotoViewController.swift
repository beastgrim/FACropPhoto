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
    case industry(_ ration: AspectRatio)
}

public class FACropPhotoViewController: UIViewController {
    
    struct ViewState {
        var scrollViewZoom: CGFloat
        var scrollViewOffset: CGPoint
        var scrollViewSize: CGSize
        var rotationAngle: CGFloat
        var cropControlFrame: CGRect
    }
    
    struct UpdateAction: OptionSet {
        public let rawValue: Int

        static let offset = UpdateAction(rawValue: 1<<0)
        static let zoom =   UpdateAction(rawValue: 1<<1)
        static let crop =   UpdateAction(rawValue: 1<<2)
        static let size =   UpdateAction(rawValue: 1<<3)
        static let rotate = UpdateAction(rawValue: 1<<4)
        static let inset =  UpdateAction(rawValue: 1<<5)
        
        static let all: UpdateAction = [.offset, .zoom, .crop, .size, .rotate, .inset]
    }
    
    struct Const {
        static var controlsHeight: CGFloat = 44.0
    }
    
    public let image: UIImage
    public private(set) var cropAspectRatio: FACropAspectRatio?
    private(set) var viewState: ViewState
    private(set) var contentView: UIView!
    private(set) var controlsContentView: UIView!
    private(set) var imageContainerView: UIView!
    private(set) var scrollView: UIScrollView!
    private(set) var imageView: UIImageView!
    private(set) var cropControl: FACropControl!
    public var imageCropRect: CGRect {
        
        let scale = self.image.scale
        var fullRect = CGRect(origin: .zero, size: self.image.size)
        fullRect.size.width *= scale
        fullRect.size.height *= scale
        
        guard self.isViewLoaded else {
  
            return fullRect
        }
        
        let inset = self.scrollView.contentInset
        let zoomScale = self.scrollView.zoomScale/self.image.scale
        var imagePoint = self.scrollView.contentOffset
        imagePoint.x += inset.left
        imagePoint.y += inset.top
        imagePoint.x /= zoomScale
        imagePoint.y /= zoomScale
        
        var imageSize = self.viewState.cropControlFrame.size
        imageSize.width /= zoomScale
        imageSize.height /= zoomScale
        
        let cropRect = CGRect(origin: imagePoint, size: imageSize)
        
        return cropRect
    }

    
    // MARK: - Life Cycle
    
    public init(image: UIImage) {
        self.image = image
        self.viewState = ViewState(scrollViewZoom: 1.0,
                                   scrollViewOffset: .zero,
                                   scrollViewSize: .zero,
                                   rotationAngle: 0.0,
                                   cropControlFrame: .zero)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Override
    
    override public func loadView() {
        super.loadView()
        
        self.view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        self.view.frame = self.view.frame.extendTo(minSize: CGSize(width: 240, height: 320))
        let bounds = self.view.bounds
        
        let controlsHeight: CGFloat = Const.controlsHeight
        
        let contentView = UIView(frame: bounds.croppedBy(side: controlsHeight, options: .bottom))
        contentView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        self.view.addSubview(contentView)
        self.contentView = contentView
        
        let controlsView = UIView(frame: bounds.with(height: controlsHeight, options: .bottom))
        controlsView.autoresizingMask = [.flexibleWidth,.flexibleTopMargin]
        self.view.addSubview(controlsView)
        self.controlsContentView = controlsView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false

        let scrollView = UIScrollView(frame: self.contentView.bounds)
        scrollView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.contentView.addSubview(scrollView)
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
        cropControl.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        cropControl.addTarget(self, action: #selector(cropControlDidChangeValue(_:)), for: .valueChanged)
        cropControl.rotateView.addTarget(self, action: #selector(cropControlDidChangeAngle(_:)), for: .valueChanged)
        cropControl.rotateView.isHidden = true
        self.contentView.addSubview(cropControl)
        self.cropControl = cropControl

        scrollView.addGestureRecognizer(cropControl.panGestureRecognizer)
        cropControl.isUserInteractionEnabled = false
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
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.viewState.scrollViewSize = self.scrollView.bounds.size
        
        if self.isFirstAppear {
            self.setupScrollView()
        } else {
            self.alignCropToCenter()
        }
    }
    
    public override func viewSafeAreaInsetsDidChange() {
        if #available(iOS 11.0, *) {
            super.viewSafeAreaInsetsDidChange()
            
            let insets = self.view.safeAreaInsets
            self.controlsContentView.frame = self.view.bounds
                .with(height: Const.controlsHeight, options: .bottom)
                .offsetBy(dx: 0, dy: -insets.bottom)
            self.contentView.frame = self.view.bounds
                .croppedBy(y: insets.top)
                .croppedBy(side: insets.bottom+Const.controlsHeight, options: .bottom)
            self.scrollView.frame = self.contentView.bounds
            self.cropControl.frame = self.scrollView.frame
            self.viewState.scrollViewSize = self.scrollView.bounds.size
        }
    }
    
    
    // MARK: - Public
    
    public func resetCropping(animated: Bool = false) {
        
        let doBlock = {
            self.setupScrollView(animated: animated)
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: FACropControl.Const.animationDuration) {
                doBlock()
            }
        } else {
            doBlock()
        }
    }
    
    public func setCropAspecRatio(_ aspectRatio: FACropAspectRatio, animated: Bool = false) {
        self.cropAspectRatio = aspectRatio

        switch aspectRatio {
        case .original:
            let ratio = self.image.size.width/self.image.size.height
            self.cropControl?.setAspectRatio(ratio)
        case .industry(let ratio):
            self.cropControl?.setAspectRatio(ratio, animated: true)
        }
        self.alignCropToCenter()
    }
    
    public func alignCropToCenter(animated: Bool = false) {
        
        guard self.isViewLoaded else { return }
        
        let selector = #selector(self.alignCropAction)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
        
        let doBlock = {
            var cropSize = self.cropControl.cropFrame.size
            let maxSize = self.cropControl.maxCropFrame.size
            let inset = self.cropControl.maxCropFrame.origin
            
            let scale = cropSize.scaleToFit(to: maxSize)
            if scale != 1.0 {
                cropSize.width *= scale
                cropSize.height *= scale
            }
            
            let cropFrame = CGRect(x: (maxSize.width-cropSize.width)/2 + inset.x,
                                   y: (maxSize.height-cropSize.height)/2 + inset.y,
                                   width: cropSize.width,
                                   height: cropSize.height)
            
            var scrollInsets = self.scrollView.contentInset
            var imagePoint = self.scrollView.contentOffset
            imagePoint.x += scrollInsets.left
            imagePoint.y += scrollInsets.top
            imagePoint.x -= inset.x
            imagePoint.y -= inset.y
            imagePoint.x /= self.scrollView.zoomScale
            imagePoint.y /= self.scrollView.zoomScale

            let newScale = self.viewState.scrollViewZoom*scale
            self.viewState.scrollViewZoom = min(self.scrollView.maximumZoomScale, newScale)
            self.viewState.cropControlFrame = cropFrame
            self.updateUI(animated: animated)
            
            scrollInsets = self.scrollView.contentInset
            var offset = imagePoint
            offset.x *= self.viewState.scrollViewZoom
            offset.y *= self.viewState.scrollViewZoom
            offset.x -= scrollInsets.left
            offset.y -= scrollInsets.top
            offset.x += inset.x
            offset.y += inset.y
            
            self.viewState.scrollViewOffset = offset
            self.updateUI(animated: animated)
            
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: FACropControl.Const.animationDuration, animations: doBlock)
        } else {
            doBlock()
        }
    }
    
    public func createCroppedImage() -> UIImage {
        
        if Thread.isMainThread, #available(iOS 10.0, *) {
            os_log("[WARNING]: You should call this function in background thread!")
        }
        
        let cropRect = self.imageCropRect
        
        if let cgImage = self.image.cgImage {
            let orientation = self.image.imageOrientation
            let scale = self.image.scale
            var fullRect = CGRect(origin: .zero, size: self.image.size)
            fullRect.size.width *= scale
            fullRect.size.height *= scale
            // Apply orientation
            let cgCropRect = cropRect.appliedImageOrientation(orientation, with: fullRect.size)
            
            if let cropped = cgImage.cropping(to: cgCropRect) {
                let croppedImage = UIImage(cgImage: cropped,
                                           scale: self.image.scale,
                                           orientation: self.image.imageOrientation)
                return croppedImage
            }
        } else if let ciImage = self.image.ciImage {
            // Convert to another coordinate system (0,0) -> bottom,left
            var ciCropRect = cropRect
            ciCropRect.origin.y = ciImage.extent.height - cropRect.maxY
            
            if let cgImage = CIContext().createCGImage(ciImage, from: ciCropRect) {
                let croppedImage = UIImage(cgImage: cgImage,
                                           scale: self.image.scale,
                                           orientation: self.image.imageOrientation)
                
                return croppedImage
            }
        } else {
            if #available(iOS 10.0, *) {
                os_log("[ERROR] %@: Image not supported: %@", #function, self.image)
            }
        }
        
        return self.image
    }

    
    
    // MARK: - Actions

    @objc private func cropControlDidChangeValue(_ cropControl: FACropControl) {
        self.viewState.cropControlFrame = cropControl.cropFrame

        self.updateUI(animated: false, options: [.crop, .inset])
    }
    
    @objc private func cropControlDidChangeAngle(_ angleControl: FARotationControl) {
        self.viewState.rotationAngle = angleControl.rotationAngel
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
    
    
    // MARK: - Private
    private var isFirstAppear = true
    private var swipeToBackGestureIsOn: Bool = false
    
    private func setupScrollView(animated: Bool = false) {
        
        let inset = self.cropControl.maxCropFrame.origin
        var cropMaxSize = self.scrollView.bounds.size
        cropMaxSize.width -= inset.x*2
        cropMaxSize.height -= inset.y*2
        let imageSize = self.imageView.bounds.size
        let fitScale = imageSize.scaleToFit(to: cropMaxSize)
        
        var cropFrame: CGRect = .zero
        cropFrame.size = CGSize(width: imageSize.width*fitScale, height: imageSize.height*fitScale)
        cropFrame.origin = CGPoint(x: (cropMaxSize.width-cropFrame.width)/2,
                                   y: (cropMaxSize.height-cropFrame.height)/2)
        cropFrame = cropFrame.offsetBy(dx: inset.x, dy: inset.y)
        
        self.scrollView.minimumZoomScale = 0.0
        
        self.viewState.scrollViewZoom = fitScale
        self.viewState.scrollViewOffset = .zero
        self.viewState.cropControlFrame = cropFrame
        self.viewState.rotationAngle = 0.0
        
        self.updateUI(animated: animated)
    }
    
    private func calculateScrollViewInset() -> UIEdgeInsets {
        
        let cropRect = self.cropControl.convert(self.cropControl.cropFrame, to: nil)
        let scrollRect = self.contentView.convert(self.scrollView.frame, to: nil)
        let top = cropRect.minY - scrollRect.minY
        let left = cropRect.minX - scrollRect.minX
        let bottom = scrollRect.maxY - cropRect.maxY
        let right = scrollRect.maxX - cropRect.maxX
        
        let insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        return insets
    }
    
    private func updateUI(animated: Bool = false, options: UpdateAction? = nil) {
        var state = self.viewState
        let action = options ?? .all
        
        if action.contains(.size) {
            if self.scrollView.frame.size != state.scrollViewSize {
                self.scrollView.frame.size = state.scrollViewSize
            }
        }
        
        if action.contains(.zoom) {
            let size = state.cropControlFrame.size
            let minScale = self.imageView.bounds.size.scaleToFill(to: size)
            if self.scrollView.minimumZoomScale != minScale {
                self.scrollView.minimumZoomScale = minScale
            }
            if state.scrollViewZoom < minScale {
                state.scrollViewZoom = minScale
            }
            
            if self.scrollView.zoomScale != state.scrollViewZoom {
                self.scrollView.zoomScale = state.scrollViewZoom
            }
        }

        if action.contains(.offset) {
            let contentOffset = state.scrollViewOffset
            if self.scrollView.contentOffset != contentOffset {
                self.scrollView.contentOffset = contentOffset
            }
        }

        if action.contains(.rotate) {
            let transform = CGAffineTransform(rotationAngle: state.rotationAngle)
            let transform3D = CATransform3DMakeAffineTransform(transform)
            if !CATransform3DEqualToTransform(self.imageView.layer.transform, transform3D) {
                self.imageView.layer.transform = transform3D
            }
        }

        if action.contains(.crop) {
            if !self.cropControl.cropFrame.equalTo(state.cropControlFrame) {
                self.cropControl.setCropFrame(state.cropControlFrame, animated: animated)
            }
        }

        if action.contains(.inset) {
            
            let contentInset = self.calculateScrollViewInset()
            if self.scrollView.contentInset != contentInset {
                self.scrollView.contentInset = contentInset
            }
        }
        
        // Fix bug scollView when set zero inset
        if self.scrollView.zoomScale == self.scrollView.minimumZoomScale,
            self.scrollView.contentOffset == .zero {
            let inset = self.scrollView.contentInset
            self.scrollView.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
        }
        
        self.viewState = state
    }

}


//MARK: - Scroll View Delegate
extension FACropPhotoViewController: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageContainerView
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.disableAlign()
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        self.disableAlign()
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.debounceAlign()
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        self.debounceAlign()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.viewState.scrollViewOffset = scrollView.contentOffset
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.viewState.scrollViewZoom = scrollView.zoomScale
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

