//
//  IntroViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class IntroViewController: UIViewController {
  
  @IBAction func letsGoAction(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "DiscoverViewController")
    self.present(viewController, animated: true)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()

    CCLog.warning("didReceiveMemoryWarning")
  }
  
}
