//
//  FiltersViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit
import SwiftRangeSlider


protocol FiltersViewReturnDelegate: class {
  func filterCompleteReturn(_ filter: FoodieFilter)
}



class FiltersViewController: OverlayViewController {
  
  // MARK: - Public Instance Variable
  
  weak var delegate: FiltersViewReturnDelegate?
  var parentNavController: UINavigationController?
  var workingFilter: FoodieFilter!
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet var selectedLabel: UILabel!
  @IBOutlet var priceSlider: RangeSlider!
  @IBOutlet var priceRangeView: UIView!
  
  
  
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
  
  
  @IBAction func priceSliderValuesChanged(_ priceSlider: RangeSlider) {
    FoodieFilter.main.priceLowerLimit = priceSlider.lowerValue
    FoodieFilter.main.priceUpperLimit = priceSlider.upperValue
  }
  

  
  // MARK: - Private Instance Function
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    parentNavController?.popViewController(animated: true)
  }
  
  
  @objc private func clearAction(_ sender: UIBarButtonItem) {
    FoodieCategory.setAllSelection(to: .unselected)
    workingFilter.resetAll()
    
    priceSlider.lowerValue = workingFilter.priceLowerLimit
    priceSlider.upperValue = workingFilter.priceUpperLimit
    updateSelectedCategoriesLabel()
  }
  
  
  private func updateSelectedCategoriesLabel() {
    if workingFilter.selectedCategories.count > 0 {
      if workingFilter.selectedCategories.count == 1, let name = workingFilter.selectedCategories[0].name {
        selectedLabel.text = name
      } else {
        selectedLabel.text = "\(workingFilter.selectedCategories.count) selected"
      }
      selectedLabel.isHidden = false
    } else {
      selectedLabel.isHidden = true
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let leftArrowImage = UIImage(named: "Settings-CrossDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearAction(_:)))
    
    let titleTextAttributes = [NSAttributedStringKey.font : UIFont(name: "Raleway-Semibold", size: 14)!,
                               NSAttributedStringKey.strokeColor : FoodieGlobal.Constants.TextColor]
    navigationItem.rightBarButtonItem!.setTitleTextAttributes(titleTextAttributes, for: .normal)
    navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.ThemeColor
    
    
    if workingFilter == nil {
      workingFilter = FoodieFilter.main
    }
    
    priceSlider.lowerValue = workingFilter.priceLowerLimit
    priceSlider.upperValue = workingFilter.priceUpperLimit
    updateSelectedCategoriesLabel()
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
    
    delegate?.filterCompleteReturn(workingFilter)
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
