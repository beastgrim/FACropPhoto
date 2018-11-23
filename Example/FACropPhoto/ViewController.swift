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

    weak var cropVC: FACropPhotoViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.view.backgroundColor = .white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let cropVC = self.cropVC {
            
            let image = cropVC.createCroppedImage()

            print("Crop image: \(image)")
        }
        
        if let image = UIImage(named: "img") {
            
            let vc = FACropPhotoViewController(image: image)
            vc.navigationItem.rightBarButtonItems  = [
                UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(setRatio(_:))),
                UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(align(_:)))]
            self.navigationController?.pushViewController(vc, animated: true)
//            self.present(vc, animated: true, completion: nil)
            self.cropVC = vc
        }
    }
    
    @objc func dismissAction(_ sender: Any?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func setRatio(_ sender: Any?) {
        
        let cases = AspectRatio.allCases
        let ratio = cases[Int(arc4random()%UInt32(cases.count))]
        self.cropVC?.setCropAspecRatio(FACropAspectRatio.industry(ratio), animated: true)
    }
    
    @objc func align(_ sender: Any?) {
        self.cropVC?.alignCropToCenter(animated: true)
    }

}

