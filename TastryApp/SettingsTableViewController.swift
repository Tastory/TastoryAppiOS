//
//  SettingsTableViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class SettingsTableViewController: UITableViewController {
  
  var parentNavController: UINavigationController?
  
  @objc private func logOutAction(_ sender: UIBarButtonItem) {
    LogOutDismiss.askDiscardIfNeeded(from: self)
  }
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    if let parentNavController = parentNavController {
      parentNavController.popViewController(animated: true)
    } else {
      dismiss(animated: true)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(dismissAction(_:)))
    // navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logOutAction(_:)))
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
  
  // MARK: - TableViewController Delegate Protocol Conformance
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
    guard let navigationController = navigationController else {
      CCLog.fatal("navigationController = nil")
    }
    
    let storyboard = UIStoryboard(name: "Settings", bundle: nil)
    var pushViewController: OverlayViewController?
  
    if indexPath.section == 0, indexPath.row == 0 {
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ProfileDetailViewController") as? ProfileDetailViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of ProfileDetailViewController Class!!")
        }
        return
      }
      pushViewController = viewController
    }
    
    else if indexPath.section == 0, indexPath.row == 1 {
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "PasswordViewController") as? PasswordViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("ViewController initiated not of PasswordViewController Class!!")
        }
        return
      }
      pushViewController = viewController
    }
    
    else if indexPath.section == 1, indexPath.row == 0 {
      
    }
      
    else if indexPath.section == 1, indexPath.row == 1 {
      
    }
      
    else if indexPath.section == 2, indexPath.row == 0 {
      
    }
    
    else if indexPath.section == 2, indexPath.row == 1 {
      
    }
    
    else if indexPath.section == 2, indexPath.row == 2 {
      
    }
      
    else if indexPath.section == 2, indexPath.row == 3 {
      
    }
      
    else if indexPath.section == 3, indexPath.row == 0 {
      LogOutDismiss.askDiscardIfNeeded(from: self)
    }
    
    else {
      CCLog.fatal("IndexPath section: \(indexPath.section), row: \(indexPath.row) does not exist for Settings Static Table")
    }
    
    if let viewController = pushViewController {
      viewController.setSlideTransition(presentTowards: .left, withGapSize: 5.0, dismissIsInteractive: true)
      navigationController.pushViewController(viewController, animated: true)
    }
  }
}
