//
//  MealTableViewController.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-16.
//  Copyright © 2018 Tastry. All rights reserved.
//

import UIKit
import CoreLocation

protocol MealReturnDelegate: class {
  func completedSelection(selectedMeals: [MealType])
}


class MealTableViewController: OverlayViewController {

  // MARK: - Constants
  private struct Constants {
    static let StackShadowOffset = FoodieGlobal.Constants.DefaultUIShadowOffset
    static let StackShadowRadius = FoodieGlobal.Constants.DefaultUIShadowRadius
    static let StackShadowOpacity = FoodieGlobal.Constants.DefaultUIShadowOpacity
  }

  
  // MARK: - Public Instance Variables
  var mealType: [MealType]?
  var delegate: MealReturnDelegate? = nil

  // MARK: - IBOutlet
  @IBOutlet weak var stackView: UIStackView!
  @IBOutlet weak var mealTableView: UITableView!


  // MARK: - IBActions
  @IBAction func leftBarButtonAction(_ sender: UIButton) {
     popDismiss(animated: true)
  }

  @IBAction func doneAction(_ sender: UIButton) {
    guard let mealType = mealType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("mealType is nil")
      }
      return
    }
    delegate?.completedSelection(selectedMeals: mealType)

    popDismiss(animated: true)
  }

  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    mealTableView.allowsSelection = false
    mealTableView.dataSource = self
    mealTableView.register(UINib.init(nibName: String(describing: CategoryTableViewCell.self), bundle: nil), forCellReuseIdentifier: "CategoryCell")

    // Drop Shadow at the back of the View
    view.layer.masksToBounds = false
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOffset = Constants.StackShadowOffset
    view.layer.shadowRadius = Constants.StackShadowRadius
    view.layer.shadowOpacity = Constants.StackShadowOpacity

  }
}

// MARK: - Table View Data Source Protocol Conformance
extension MealTableViewController: UITableViewDataSource {

  func numberOfSections(in tableView: UITableView) -> Int {
    return 1  // Hard coded to 1 for now?
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return MealType.types.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath) as? CategoryTableViewCell else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("TableView dequeued nil or non-CategoryTableViewCell")
      }
      return UITableViewCell()  // Return some new cell to prevent crashing
    }

    // used for earl grey testing
    cell.accessibilityLabel = "mealTableViewCell"
    cell.accessibilityTraits = UIAccessibilityTraitButton
    cell.isAccessibilityElement = true
    cell.isUserInteractionEnabled = true

    cell.delegate = self
    cell.expandButton.isHidden =  true
    let mealTypeStr = MealType.types[indexPath.row].rawValue
    cell.titleLabel.text = mealTypeStr
    if mealType != nil, mealType!.contains(MealType.types[indexPath.row]) {
      cell.setRadio(to: .selected)
    }
    return cell
  }
}

// MARK: - Category Table View Cell Delegate Protocol Conformance
extension MealTableViewController: CategoryTableViewCellDelegate {
  func expandCollpase(for cell: CategoryTableViewCell, to state: CategoryTableViewCell.ExpandCollapseState) {
    // Do Nothing
  }

  func selection(for cell: CategoryTableViewCell, to state: FoodieCategory.SelectionState) {

    guard let mealText = cell.titleLabel.text else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Title of label cell is missing")
      }
      return
    }

    guard let selectedType = MealType(rawValue: mealText) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Failed to initialize meal type enum")
      }
      return
    }

    if mealType != nil {
      if state == .selected {
        if mealType!.index(of: selectedType) == nil {
          mealType!.append(selectedType)
        }

        if selectedType == .brunch {

          if mealType!.index(of: MealType.breakfast) == nil {
            mealType!.append(MealType.breakfast)
          }

          if mealType!.index(of: MealType.lunch) == nil {
            mealType!.append(MealType.lunch)
          }
          mealTableView.reloadData()
        }

      } else if state == .unselected {
        if let index = mealType!.index(of: selectedType) {
          mealType!.remove(at: index)
        }
      }
    } else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("selectedMeal is nil")
      }
      return
    }
  }
}

