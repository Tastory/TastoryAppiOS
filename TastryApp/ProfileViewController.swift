//
//  ProfileViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class ProfileViewController: TransitableViewController {
  
  
  // MARK: - Public Instance Variable
  
  var user: FoodieUser?
  
  
  // MARK: - IBAction
  
  @IBAction func logOutAction(_ sender: UIBarButtonItem) {
    LogOutDismiss.askDiscardIfNeeded(from: self)
  }
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
}
