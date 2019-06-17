//
//  ViewController.swift
//  FACropPhoto
//
//  Created by beastgrim on 11/21/2018.
//  Copyright (c) 2018 beastgrim. All rights reserved.
//

import UIKit
//import FACropPhoto


class ViewController: UIViewController {

    var cropVC: FACropPhotoViewController?
    weak var imageView: UIImageView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.view.backgroundColor = .white
        
        let imageView = UIImageView(frame: self.view.bounds)
        imageView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        self.view.addSubview(imageView)
        self.imageView = imageView
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editAction(_:)))
    }
    
    @objc func dismissAction(_ sender: Any?) {
        let isCropped = self.cropVC!.isCropped
        print("Is cropped: \(isCropped)")
        
        self.cropVC?.navigationController?.popViewController(animated: true)
        self.imageView?.image = self.cropVC?.createCroppedImage()
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func setRatio(_ sender: Any?) {
        
        let cases = AspectRatio.allCases
        let ratio = cases[Int(arc4random()%UInt32(cases.count))]
        self.cropVC?.setCropAspecRatio(FACropAspectRatio.industry(ratio), animated: true)
        
        let image = UIImage.generateIcon(size: CGSize(width: 80, height: 80), aspectRatio: ratio)
        print("\(image)")
    }
    
    @objc func align(_ sender: Any?) {
        self.cropVC?.resetCropping(animated: true)
    }
    
    @objc func editAction(_ sender: Any?) {
        
        if var image = UIImage(named: "img") {
            
//            let ciImage = CIImage(image: image)!
//            var image = UIImage(ciImage: ciImage)
            
            var options = FACropPhotoOptions()
            options.showControls = true
            options.controlsHeight = 44.0
//            if scale {
//                image = UIImage(ciImage: ciImage, scale: 2.0, orientation: .up)
                image = UIImage(cgImage: image.cgImage!, scale: UIScreen.main.scale, orientation: .up)
//                self.cropVC?.image = image
//            }
            if let cropVC = self.cropVC {
                cropVC.initialCropRect = CGRect(x: 492.869598, y: 144.000397, width: 612.129272, height: 805.388732)
            }
            let vc = self.cropVC ?? FACropPhotoViewController(image: image, options: options)

            vc.navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(setRatio(_:))),
                UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(align(_:)))]
            self.navigationController?.pushViewController(vc, animated: true)
            self.navigationController?.navigationBar.isTranslucent = false
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissAction(_:)))
            self.cropVC = vc
        }
    }

}

