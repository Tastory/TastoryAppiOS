//
//  DiscoverViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class DiscoverViewController: TransitableViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  override func viewDidAppear(_ animated: Bool) {
    
    // TODO: Factor out all View Controller creation and presentation? code for state restoration purposes
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MapViewController")  // This is a dangerous implementation. If a child view gets dismissed, this actually gets called immediately, and presents the child view again.
    self.present(viewController, animated: true)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}
