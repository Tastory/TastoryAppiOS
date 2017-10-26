//
//  ProfileDetailViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-22.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class PasswordViewController: TransitableViewController {
  
  var passwordTableViewController: PasswordTableViewController?
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    navigationController?.delegate = self
    navigationItem.title = "Password Change"
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "PasswordTableViewController") as? PasswordTableViewController else {
      CCLog.fatal("Cannot cast ViewController from Storyboard to PasswordTableViewController")
    }

    addChildViewController(viewController)
    view.addSubview(viewController.view)
    viewController.view.frame = view.bounds
    viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    viewController.didMove(toParentViewController: self)
    passwordTableViewController = viewController
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
  /*
   // MARK: - Navigation
   
   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
   // Get the new view controller using segue.destinationViewController.
   // Pass the selected object to the new view controller.
   }
   */
  
}
