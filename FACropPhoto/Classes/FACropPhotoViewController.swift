//
//  FACropPhotoViewController.swift
//  FACropPhoto
//
//  Created by Evgeny Bogomolov on 21/11/2018.
//

import UIKit

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
    
    public let image: UIImage
    public private(set) var cropAspectRatio: FACropAspectRatio?
    private(set) var viewState: ViewState
    private(set) var contentView: UIView!
    private(set) var controlsContentView: UIView!
    private(set) var imageContainerView: UIView!
    private(set) var scrollView: UIScrollView!
    private(set) var imageView: UIImageView!
    private(set) var cropControl: FACropControl!

    
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
        
        let controlsHeight: CGFloat = 44.0
        
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
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.backgroundColor = .brown
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
        cropControl.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        cropControl.addTarget(self, action: #selector(cropControlDidChangeValue(_:)), for: .valueChanged)
        cropControl.rotateView.addTarget(self, action: #selector(cropControlDidChangeAngle(_:)), for: .valueChanged)
        cropControl.rotateView.isHidden = true
        self.contentView.addSubview(cropControl)
        self.cropControl = cropControl
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
            self.scrollView.frame = self.contentView.bounds.croppedBy(y: insets.top)
            self.cropControl.frame = self.scrollView.frame
            self.viewState.scrollViewSize = self.scrollView.bounds.size
        }
    }
    
    
    // MARK: - Public
    
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
            let scrollSize = self.scrollView.bounds.size
            
            let scale = cropSize.scaleToFit(to: scrollSize)
            if scale != 1.0 {
                cropSize.width *= scale
                cropSize.height *= scale
            }
            
            let cropFrame = CGRect(x: (scrollSize.width-cropSize.width)/2,
                                   y: (scrollSize.height-cropSize.height)/2,
                                   width: cropSize.width,
                                   height: cropSize.height)
            
            var scrollInsets = self.scrollView.contentInset
            var imagePoint = self.scrollView.contentOffset
            imagePoint.x += scrollInsets.left
            imagePoint.y += scrollInsets.top
            imagePoint.x /= self.scrollView.zoomScale
            imagePoint.y /= self.scrollView.zoomScale

            self.viewState.scrollViewZoom *= scale
            self.viewState.cropControlFrame = cropFrame
            self.updateUI()

            self.updateScrollInsets()
            
            scrollInsets = self.scrollView.contentInset
            var offset = imagePoint
            offset.x *= self.viewState.scrollViewZoom
            offset.y *= self.viewState.scrollViewZoom
            offset.x -= scrollInsets.left
            offset.y -= scrollInsets.top
            
            self.viewState.scrollViewOffset = offset
            self.updateUI()
            
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.24, animations: doBlock)
        } else {
            doBlock()
        }
    }

    
    // MARK: - Actions

    @objc private func cropControlDidChangeValue(_ cropControl: FACropControl) {
        self.viewState.cropControlFrame = cropControl.cropFrame

        self.updateScrollInsets()
        self.updateUI()
        
        self.debounceAlign()
    }
    
    @objc private func cropControlDidChangeAngle(_ angleControl: FARotationControl) {
        self.viewState.rotationAngle = angleControl.rotationAngel
        self.updateUI()
    }
    
    private func debounceAlign() {
        let selector = #selector(self.alignCropAction)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: selector, object: nil)
        self.perform(selector, with: nil, afterDelay: 1)
    }
    
    @objc private func alignCropAction() {
        self.alignCropToCenter(animated: true)
    }

    
    // MARK: - Private
    private var isFirstAppear = true
    private var swipeToBackGestureIsOn: Bool = false
    
    private func setupScrollView() {
        
        let scrollSize = self.scrollView.bounds.size
        let imageSize = self.imageView.bounds.size
        let scale = imageSize.scaleToFit(to: scrollSize)
        
        var cropFrame: CGRect = .zero
        cropFrame.size = CGSize(width: imageSize.width*scale, height: imageSize.height*scale)
        cropFrame.origin = CGPoint(x: (scrollSize.width-cropFrame.width)/2,
                                   y: (scrollSize.height-cropFrame.height)/2)

        
        self.scrollView.minimumZoomScale = 0.0
        
        self.viewState.scrollViewZoom = scale
        self.viewState.scrollViewOffset = .zero
        self.viewState.cropControlFrame = cropFrame
        self.viewState.rotationAngle = 0.0
        
        self.updateUI()
        self.updateScrollInsets()
    }
    
    private func updateScrollInsets() {

        let cropRect = self.cropControl.convert(self.cropControl.cropFrame, to: nil)
        let scrollRect = self.contentView.convert(self.scrollView.frame, to: nil)
        let top = cropRect.minY - scrollRect.minY
        let left = cropRect.minX - scrollRect.minX
        let bottom = scrollRect.maxY - cropRect.maxY
        let right = scrollRect.maxX - cropRect.maxX
        
        self.scrollView.contentInset = UIEdgeInsetsMake(top, left, bottom, right)
    }
    
    private func updateUI() {
        var state = self.viewState
        
        if self.scrollView.frame.size != state.scrollViewSize {
            self.scrollView.frame.size = state.scrollViewSize
        }
        
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
        
        let contentOffset = state.scrollViewOffset
        if self.scrollView.contentOffset != contentOffset {
            self.scrollView.contentOffset = contentOffset
        }
        let transform = CGAffineTransform(rotationAngle: state.rotationAngle)
        let transform3D = CATransform3DMakeAffineTransform(transform)
        if !CATransform3DEqualToTransform(self.imageView.layer.transform, transform3D) {
            self.imageView.layer.transform = transform3D
        }
        if !self.cropControl.cropFrame.equalTo(state.cropControlFrame) {
            self.cropControl.cropFrame = state.cropControlFrame
        }
        
        self.viewState = state
    }

}


//MARK: - Scroll View Delegate
extension FACropPhotoViewController: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageContainerView
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.viewState.scrollViewOffset = scrollView.contentOffset
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.viewState.scrollViewZoom = scrollView.zoomScale
    }
}

