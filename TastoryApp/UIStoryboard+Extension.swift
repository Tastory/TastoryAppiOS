//
//  UIStoryboard+Extensions.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

extension UIStoryboard {

  func instantiateFoodieViewController(withIdentifier identifier: String) -> UIViewController {
    let viewController = instantiateViewController(withIdentifier: identifier)
    viewController.restorationIdentifier = identifier
    return viewController
  }
}
