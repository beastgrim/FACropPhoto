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
        
        static let all: UpdateAction = [.offset, .zoom, .crop, .size, .rotate, .inset, .ratio]
    }
    
    struct Const {
        static var controlsHeight: CGFloat = 44.0
    }
    public var initialCropRect: CGRect? {
        didSet {
            if self.isViewLoaded {
                self.disableAllAnimations()
                self.cropAspectRatio = nil
                self.viewState.aspectRatio = nil
                self.viewState.scrollViewZoom = 1.0
                self.setupScrollView()
            }
        }
    }
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
    private(set) var viewState: ViewState
    private(set) var contentView: UIView!
    private(set) var controlsContentView: UIView!
    private(set) var imageContainerView: UIView!
    private(set) var scrollView: UIScrollView!
    private(set) var imageView: UIImageView!
    private(set) var aspectRatioControl: FAAspectRatioControl!
    public var imageCropRect: CGRect {

        guard self.isViewLoaded else {
            return CGRect(origin: .zero, size: self.image.size)
        }
        
        let inset = self.viewState.scrollViewInset
        let zoomScale = self.viewState.scrollViewZoom
        var imagePoint = self.viewState.scrollViewOffset
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
    
    public var imageBitmapCropRect: CGRect {
        var rect = self.imageCropRect
        let scale = self.image.scale
        rect.size.width *= scale
        rect.size.height *= scale
        rect.origin.x *= scale
        rect.origin.y *= scale
        return rect
    }

    public var isCropped: Bool {
        var isCropped = false
        if let scrollView = self.scrollView {
            isCropped = scrollView.zoomScale != scrollView.minimumZoomScale
        }
        let imageRatio = self.image.size.width/self.image.size.height
        let cropSize = self.viewState.cropControlFrame.size
        let cropRatio = cropSize.width/cropSize.height
        isCropped = isCropped || abs(imageRatio-cropRatio) > 0.00001
        
        return isCropped
    }
    
    
    // MARK: - Life Cycle
    
    public init(image: UIImage, options: FACropPhotoOptions = FACropPhotoOptions()) {
        self.image = image
        self.options = options
        self.viewState = ViewState.initial
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
        
        let controlsHeight: CGFloat = self.options.controlsHeight
        
        let contentView = UIView(frame: bounds.croppedBy(side: controlsHeight, options: .bottom))
        contentView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
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
        self.observations += [
            scrollView.observe(\.contentInset, options: [.initial,.new]) { [unowned self] (scrollView, _) in
            self.viewState.scrollViewInset = scrollView.contentInset
        }]
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
        self.disableAllAnimations()
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
                .croppedBy(side: insets.bottom+self.options.controlsHeight, options: .bottom)
            self.scrollView.frame = self.contentView.bounds
            self.cropControl.frame = self.scrollView.frame
            self.viewState.scrollViewSize = self.scrollView.bounds.size
        }
    }
    
    
    // MARK: - Public
    
    @objc public func resetCropping(_ sender: Any?) {
        self.resetCropping(animated: true)
    }
    
    public func resetCropping(animated: Bool = false) {
        
        let doBlock = {
            self.scrollView?.isScrollEnabled = false
            self.scrollView?.isScrollEnabled = true
            self.initialCropRect = nil
            self.cropAspectRatio = nil
            self.viewState.aspectRatio = nil
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
            var cropSize = self.cropControl.cropFrame.size
            let maxSize = self.cropControl.maxCropFrame.size
            let inset = self.cropControl.maxCropFrame.origin
            
            let scale = cropSize.scaleToFit(to: maxSize)
            if scale != 1.0 {
                cropSize.width *= scale
                cropSize.height *= scale
            }
            
            var scrollInsets = self.scrollView.contentInset
            var imagePoint = self.scrollView.contentOffset
            imagePoint.x += scrollInsets.left
            imagePoint.y += scrollInsets.top
            imagePoint.x /= self.scrollView.zoomScale
            imagePoint.y /= self.scrollView.zoomScale
            
            let cropFrame = CGRect(x: (maxSize.width-cropSize.width)/2 + inset.x,
                                   y: (maxSize.height-cropSize.height)/2 + inset.y,
                                   width: cropSize.width,
                                   height: cropSize.height)
            
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
        
        return self.image.crop(with: self.imageCropRect)
    }
    
    
    // MARK: - Actions

    @objc private func cropControlDidChangeValue(_ cropControl: FACropControl) {
        self.viewState.cropControlFrame = cropControl.cropFrame

        self.updateUI(animated: false, options: [.crop, .inset, .zoom])
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
    
    private func setupScrollView(animated: Bool = false) {
        
        let inset = self.cropControl.maxCropFrame.origin
        var cropMaxSize = self.scrollView.bounds.size
        cropMaxSize.width -= inset.x*2
        cropMaxSize.height -= inset.y*2
        
        self.scrollView.minimumZoomScale = 0.0

        if let initialCrop = self.initialCropRect {
            
            let initialScale = initialCrop.size.scaleToFit(to: cropMaxSize)
            self.viewState.scrollViewZoom = initialScale
            self.updateUI(animated: false, options: [.zoom])

            var initialCropFrame: CGRect = .zero
            let imageSize = initialCrop.size
            initialCropFrame.size = CGSize(width: imageSize.width*initialScale, height: imageSize.height*initialScale)
            initialCropFrame.origin = CGPoint(x: (cropMaxSize.width-initialCropFrame.width)/2,
                                              y: (cropMaxSize.height-initialCropFrame.height)/2)
            initialCropFrame = initialCropFrame.offsetBy(dx: inset.x, dy: inset.y)
            self.viewState.cropControlFrame = initialCropFrame

            self.viewState.scrollViewOffset = CGPoint(x: -initialCropFrame.origin.x+initialCrop.origin.x*initialScale,
                                                      y: -initialCropFrame.origin.y+initialCrop.origin.y*initialScale)
        
        } else {
            let imageSize = self.imageView.bounds.size
            let fitScale = imageSize.scaleToFit(to: cropMaxSize)
            var cropFrame: CGRect = .zero
            cropFrame.size = CGSize(width: imageSize.width*fitScale, height: imageSize.height*fitScale)
            cropFrame.origin = CGPoint(x: (cropMaxSize.width-cropFrame.width)/2,
                                       y: (cropMaxSize.height-cropFrame.height)/2)
            cropFrame = cropFrame.offsetBy(dx: inset.x, dy: inset.y)
            
            
            self.viewState.scrollViewZoom = fitScale
            self.viewState.scrollViewOffset = .zero
            self.viewState.cropControlFrame = cropFrame
            self.viewState.rotationAngle = 0.0
        }
        
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
        let action = options ?? .all
        
        if action.contains(.size) {
            if self.scrollView.frame.size != self.viewState.scrollViewSize {
                self.scrollView.frame.size = self.viewState.scrollViewSize
            }
        }
        
        if action.contains(.zoom) {
            let size = self.viewState.cropControlFrame.size
            let minScale = self.imageView.bounds.size.scaleToFill(to: size)
            if self.scrollView.minimumZoomScale != minScale {
                self.scrollView.minimumZoomScale = minScale
            }
            if self.viewState.scrollViewZoom < minScale {
                self.viewState.scrollViewZoom = minScale
            }
            
            if self.scrollView.zoomScale != self.viewState.scrollViewZoom {
                self.scrollView.zoomScale = self.viewState.scrollViewZoom
            }
        }

        if action.contains(.offset) {
            let contentOffset = self.viewState.scrollViewOffset
            if self.scrollView.contentOffset != contentOffset {
                self.scrollView.contentOffset = contentOffset
            }
        }

        if action.contains(.rotate) {
            let transform = CGAffineTransform(rotationAngle: self.viewState.rotationAngle)
            let transform3D = CATransform3DMakeAffineTransform(transform)
            if !CATransform3DEqualToTransform(self.imageView.layer.transform, transform3D) {
                self.imageView.layer.transform = transform3D
            }
        }

        if action.contains(.crop) {
            if !self.cropControl.cropFrame.equalTo(self.viewState.cropControlFrame) {
                self.cropControl.setCropFrame(self.viewState.cropControlFrame, animated: animated)
            }
        }

        if action.contains(.inset) {
            
            let contentInset = self.calculateScrollViewInset()
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

