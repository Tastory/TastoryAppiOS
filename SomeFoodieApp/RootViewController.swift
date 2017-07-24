//
//  RootViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  override func viewDidAppear(_ animated: Bool) {
    
    // TODO: Factor out all View Controller creation and presentation? code for state restoration purposes
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController")
    self.present(viewController, animated: true)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}
