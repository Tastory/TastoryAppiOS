//
//  FiltersViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import NMRangeSlider


class FiltersViewController: OverlayViewController {
  
  // MARK: - Public Instance Variable
  
  var parentNavController: UINavigationController?
  
  
  
  // MARK: - Private Instance Variable
  
  private var selectedCategories = [FoodieCategory]()
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet var selectedLabel: UILabel!
  @IBOutlet var rangeSlider: NMRangeSlider!
  
  
  
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
  
  
  
  // MARK: - Private Instance Function
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    parentNavController?.popViewController(animated: true)
  }
  
  
  private func updateSelectedCategoriesLabel() {
    if selectedCategories.count > 0 {
      if selectedCategories.count == 1, let name = selectedCategories[0].name {
        selectedLabel.text = name
      } else {
        selectedLabel.text = "\(selectedCategories.count) Selected"
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
    
    updateSelectedCategoriesLabel()
    
    rangeSlider.trackCrossedOverImage = #imageLiteral(resourceName: "Filters-RangeSliderHighlightTrack")
    rangeSlider.trackImage = #imageLiteral(resourceName: "Filters-RangeSliderBackgroundTrack")
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
//    navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
//    navigationController?.navigationBar.shadowImage = nil
//    navigationController?.navigationBar.clipsToBounds = false
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("didReceiveMemoryWarning")
  }
}



extension FiltersViewController: CategoryReturnDelegate {
  func categorySearchComplete(categories: [FoodieCategory]) {
    selectedCategories = categories
    updateSelectedCategoriesLabel()
  }
}
