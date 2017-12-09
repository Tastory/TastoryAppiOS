//
//  FiltersViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class FiltersViewController: OverlayViewController {
  
  // MARK: - Public Instance Variable
  
  var parentNavController: UINavigationController?
  
  
  
  // MARK: - IBAction
  
  @IBAction func categoryTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Filters", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CategoryViewController") as? CategoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of CategoryViewController Class!!")
      }
      return
    }
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  
  // MARK: - Private Instance Function
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    parentNavController?.popViewController(animated: true)
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let leftArrowImage = UIImage(named: "Settings-CrossDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
}
