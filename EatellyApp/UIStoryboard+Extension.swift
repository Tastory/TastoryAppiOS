//
//  UIStoryboard+Extensions.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-05-12.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

extension UIStoryboard {

  func instantiateFoodieViewController(withIdentifier identifier: String) -> UIViewController {
    let viewController = instantiateViewController(withIdentifier: identifier)
    viewController.restorationIdentifier = identifier
    return viewController
  }
}
