//
//  ServiceTermsViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class ServiceTermsViewController: OverlayViewController {
  
  // MARK: - IBOutlet
  
  @IBOutlet var serviceTermsTextView: UITextView!
  
  
  // MARK: - IBAction
  
  // MARK: - Private Instance Variable
  
  // MARK: - Public Instance Variable
  
  // MARK: - Private Instance Functions
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    popDismiss(animated: true)
  }
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let leftArrowImage = UIImage(named: "Settings-LeftArrowDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    
    serviceTermsTextView.textContainerInset = UIEdgeInsetsMake(15, 15, 15, 15)
    serviceTermsTextView.contentOffset = CGPoint(x: 0.0, y: 0.0)
  }
}
