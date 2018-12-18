//
//  FiltersViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit
import SwiftRangeSlider


protocol FiltersViewReturnDelegate: class {
  func filterCompleteReturn(_ filter: FoodieFilter, _ performSearch: Bool)
}



class FiltersViewController: OverlayViewController {
  
  
  // MARK: - Private Instance Variable
  private var searchOnDismiss: Bool = false
  
  
  // MARK: - Public Instance Variable
  
  weak var delegate: FiltersViewReturnDelegate?
  var parentNavController: UINavigationController?
  var workingFilter: FoodieFilter!
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet var categoriesLabel: UILabel!
  @IBOutlet var mealTypesLabel: UILabel!
  @IBOutlet var priceSlider: RangeSlider!
  @IBOutlet var priceRangeView: UIView!
  @IBOutlet var curatedSwitch: UISwitch!
  
  
  // MARK: - IBAction
  
  @IBAction func categoryTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Filters", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CategoryViewController") as? CategoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of CategoryViewController Class!!")
      }
      return
    }
    viewController.delegate = self
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func mealTypeTap(_ sender: UITapGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MealTableViewController") as? MealTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of MealTableViewController Class!!")
      }
      return
    }
    
    viewController.mealType = workingFilter.selectedMealTypes
    viewController.isInNavController = true
    viewController.delegate = self
    viewController.setSlideTransition(presentTowards: .left, withGapSize: 2.0, dismissIsInteractive: true)
    pushPresent(viewController, animated: true)
  }
  
  
  @IBAction func priceSliderValuesChanged(_ priceSlider: RangeSlider) {
    FoodieFilter.main.priceLowerLimit = priceSlider.lowerValue
    FoodieFilter.main.priceUpperLimit = priceSlider.upperValue
  }
  

  @IBAction func searchFilterAction(_ sender: UIButton) {
    searchOnDismiss = true
    parentNavController?.popViewController(animated: true)
  }
  
  
  @IBAction func switchToggled(_ sender: UISwitch) {
    FoodieFilter.main.showEverything = !sender.isOn  // On = Curated, Off = Everything
  }
  
  
  
  // MARK: - Private Instance Function
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    searchOnDismiss = false
    parentNavController?.popViewController(animated: true)
  }
  
  
  @objc private func clearAction(_ sender: UIBarButtonItem) {
    FoodieCategory.setAllSelection(to: .unselected)
    workingFilter.resetAll()
    
    priceSlider.lowerValue = workingFilter.priceLowerLimit
    priceSlider.upperValue = workingFilter.priceUpperLimit
    curatedSwitch.setOn(true, animated: true)
    updateSelectedCategoriesLabel()
    updateSelectedMealTypesLabel()
  }
  
  
  private func updateSelectedCategoriesLabel() {
    if workingFilter.selectedCategories.count > 0 {
      if workingFilter.selectedCategories.count == 1, let name = workingFilter.selectedCategories[0].name {
        categoriesLabel.text = name
      } else {
        categoriesLabel.text = "\(workingFilter.selectedCategories.count) selected"
      }
      categoriesLabel.isHidden = false
    } else {
      categoriesLabel.isHidden = true
    }
  }
  
  
  private func updateSelectedMealTypesLabel() {
    mealTypesLabel.text = ""
    
    if workingFilter.selectedMealTypes.count > 0 {
      
      for selectedMealType in workingFilter.selectedMealTypes {
        if mealTypesLabel.text!.count > 1 {
          mealTypesLabel.text! += ", "
        }
        mealTypesLabel.text! += selectedMealType.rawValue
      }
      
      mealTypesLabel.isHidden = false
    } else {
      mealTypesLabel.isHidden = true
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let leftArrowImage = UIImage(named: "Settings-CrossDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearAction(_:)))
    
    let titleTextAttributes = [NSAttributedString.Key.font : UIFont(name: "Raleway-Semibold", size: 14)!,
                               NSAttributedString.Key.strokeColor : FoodieGlobal.Constants.TextColor]
    navigationItem.rightBarButtonItem!.setTitleTextAttributes(titleTextAttributes, for: .normal)
    navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.ThemeColor
    
    
    if workingFilter == nil {
      workingFilter = FoodieFilter.main
    }
    
    priceSlider.lowerValue = workingFilter.priceLowerLimit
    priceSlider.upperValue = workingFilter.priceUpperLimit
    curatedSwitch.setOn(!workingFilter.showEverything, animated: false)
    updateSelectedCategoriesLabel()
    updateSelectedMealTypesLabel()
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
//    navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
//    navigationController?.navigationBar.shadowImage = nil
//    navigationController?.navigationBar.clipsToBounds = false
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    priceSlider.layoutIfNeeded()
    priceSlider.updateLayerFramesAndPositions()
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    delegate?.filterCompleteReturn(workingFilter, searchOnDismiss)
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
}



extension FiltersViewController: CategoryReturnDelegate {
  func categorySearchComplete(categories: [FoodieCategory]) {
    workingFilter.selectedCategories = categories
    updateSelectedCategoriesLabel()
  }
}


extension FiltersViewController: MealReturnDelegate {
  func completedSelection(selectedMeals: [MealType]) {
    workingFilter.selectedMealTypes = selectedMeals
    updateSelectedMealTypesLabel()
  }
}
