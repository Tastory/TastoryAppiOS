//
//  SettingsViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class SettingsViewController: TransitableViewController {
  
  var settingsNavController: SettingsNavController?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SettingsTableViewController") as? SettingsTableViewController else {
      CCLog.fatal("Cannot cast ViewController from Storyboard to SettingsTableViewController")
    }
    let navController = SettingsNavController(rootViewController: viewController)
    
    addChildViewController(navController)
    view.addSubview(navController.view)
    navController.view.frame = view.bounds
    navController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    navController.didMove(toParentViewController: self)
    settingsNavController = navController
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
}
