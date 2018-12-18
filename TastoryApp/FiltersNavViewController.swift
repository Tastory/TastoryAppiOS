//
//  FiltersNavViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import AsyncDisplayKit

class FiltersNavViewController: OverlayViewController {
  
  // MARK: - Constants
  struct Constants {
    static let StackShadowOffset = FoodieGlobal.Constants.DefaultUIShadowOffset
    static let StackShadowRadius = FoodieGlobal.Constants.DefaultUIShadowRadius
    static let StackShadowOpacity = FoodieGlobal.Constants.DefaultUIShadowOpacity
  }
  
  
  weak var filtersReturnDelegate: FiltersViewReturnDelegate?
  var filtersNavController: ASNavigationController?
  var workingFilter: FoodieFilter?
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let storyboard = UIStoryboard(name: "Filters", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "FiltersViewController") as? FiltersViewController else {
      CCLog.fatal("Cannot cast ViewController from Storyboard to FiltersViewController")
    }
    viewController.parentNavController = self.navigationController
    viewController.workingFilter = workingFilter
    viewController.delegate = filtersReturnDelegate
    
    let navController = ASNavigationController(rootViewController: viewController)
    navController.navigationBar.barTintColor = UIColor.white
    navController.navigationBar.tintColor = FoodieGlobal.Constants.TextColor
    
    let titleTextAttributes = [NSAttributedString.Key.font : UIFont(name: "Raleway-Medium", size: 16)!,
                               NSAttributedString.Key.strokeColor : FoodieGlobal.Constants.TextColor]
    navController.navigationBar.titleTextAttributes = titleTextAttributes
    
    addChild(navController)
    view.addSubview(navController.view)
    navController.didMove(toParent: self)
    filtersNavController = navController
    
    // Drop Shadow at the back of the View
    view.layer.masksToBounds = false
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOffset = Constants.StackShadowOffset
    view.layer.shadowRadius = Constants.StackShadowRadius
    view.layer.shadowOpacity = Constants.StackShadowOpacity
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}
