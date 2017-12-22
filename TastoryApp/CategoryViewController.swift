//
//  CategoryViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-08-12.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit
import RATreeView


protocol CategoryReturnDelegate: class {
  func categorySearchComplete(categories: [FoodieCategory])
}


class CategoryViewController: OverlayViewController {

  // MARK: - Constants
  
  struct Constants {
    fileprivate static let categoryCellReuseIdentifier = "CategoryCell"
    fileprivate static let categoryTreeViewRowHeight: CGFloat = 44.0
  }
  
  
  
  // MARK: - Public Instance Variables
  
  weak var delegate: CategoryReturnDelegate?
  var suggestedCategory: FoodieCategory?
  
  
  
  // MARK: - Private Instance Variables
  
  fileprivate var categoryName: String?
  fileprivate var categoryArray: [FoodieCategory]!  // Intentionally implicitly unwrap so will crash if accessed before viewDidLoad
  fileprivate var categoryResultArray: [FoodieCategory]?
  
  
  
  // MARK: - IBOutlet
  
  @IBOutlet weak var stackView: UIStackView!  // TODO: Review whether IBOutlets should be Optional or Forced Unwrapped
  @IBOutlet weak var categorySearchBar: UISearchBar!
  @IBOutlet weak var categoryTreeView: RATreeView!
  @IBOutlet weak var backgroundView: UIView!
  
  
  
  // MARK: - Private Instance Functions
  
  fileprivate func search() {
    DispatchQueue.global(qos: .userInitiated).async {  // Do this in the background, it's time consuming
      var categorySearchTerm = ""
      if let categoryName = self.categoryName {
        categorySearchTerm = categoryName
      } else {
        CCLog.warning("search() called with no categoryName?")
      }
      
      self.categoryResultArray = self.categoryArray.filter { category in
        
        guard let categoryName = category.name else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            if let id = category.foursquareCategoryID {
              CCLog.assert("Category with ID \(id) has no name. Filtering out categories with no name")
            } else {
              CCLog.fatal("Category doesn't even have ID!!!")
            }
          }
          return false  // Don't return categories with no name
        }
        return categoryName.localizedCaseInsensitiveContains(categorySearchTerm)
      }
      
      // Sort by seeing if the First Category should be placed ahead of the Second
      self.categoryResultArray!.sort { (firstCategory, secondCategory) -> Bool in
        guard let firstCategoryName = firstCategory.name, let secondCategoryName = secondCategory.name else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            if let firstID = firstCategory.foursquareCategoryID, let secondID = secondCategory.foursquareCategoryID {
              CCLog.assert("At least one category has no name! ID \(firstID) & \(secondID) respectively. Cannot do String comparison")
            } else {
              CCLog.fatal("At least one category doesn't even have an ID!!!")
            }
          }
          
          if firstCategory.name == nil {
            return false  // return the nameless category last
          } else {
            return true
          }
        }
        
        // Need to get the positions of match
        guard let firstRange = firstCategoryName.range(of: categorySearchTerm, options: .caseInsensitive),
          let secondRange = secondCategoryName.range(of: categorySearchTerm, options: .caseInsensitive) else {
          
          // Search term not actually in the Category names? What?
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            if let firstID = firstCategory.foursquareCategoryID, let secondID = secondCategory.foursquareCategoryID {
              CCLog.assert("At least one category doesn't contain search term! ID \(firstID) & \(secondID) respectively. Cannot do String comparison")
            } else {
              CCLog.fatal("At least one category doesn't even have an ID!!!")
            }
          }
          
          if firstCategoryName.range(of: categorySearchTerm, options: .caseInsensitive) == nil {
            return false
          } else {
            return true
          }
        }
        
        // Sort by position of match first
        if firstRange.lowerBound < secondRange.lowerBound {
          return true
        }
        else if firstRange.lowerBound > secondRange.lowerBound {
          return false
        }
        
        // Then by lower level
        else if firstCategory.catLevel < secondCategory.catLevel {
          return true
        }
          
        // What if the levels are the same?
        else if firstCategory.catLevel == secondCategory.catLevel {
          
          // Present A first, Z last, etc
          if firstCategoryName <= secondCategoryName {
            return true
          } else {
            return false
          }
          
        } else {
          return false
        }
      }
      
      // Reload the Tree View
      DispatchQueue.main.async { self.categoryTreeView.reloadData() }
    }
  }
  
  
  
  // MARK: - Private Instance Function
  
  @objc private func dismissAction(_ sender: UIBarButtonItem) {
    popDismiss(animated: true)
  }
  
  @objc private func clearAction(_ sender: UIBarButtonItem) {
    FoodieCategory.setAllSelection(to: .unselected)
    categorySearchBar.text = ""
    categoryName = nil
    categoryResultArray = nil
    categoryTreeView.reloadData()
  }
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // This might be computationally intensive. Do it first and in the background?
    DispatchQueue.global(qos: .userInitiated).async {
      self.categoryArray = FoodieCategory.list.map { return $0.value }  // Convert the dictionary into an array
      if self.categoryName != nil {
        self.search()
      }
    }
    
    // Adjust the Navigation Bar appearance so it'll blend with the Search Bar
//    navigationController?.navigationBar.clipsToBounds = true
//    navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
//    navigationController?.navigationBar.shadowImage = UIImage()
    navigationController?.delegate = self
    
    let leftArrowImage = UIImage(named: "Settings-LeftArrowDark")
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: leftArrowImage, style: .plain, target: self, action: #selector(dismissAction(_:)))
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearAction(_:)))
    
    let titleTextAttributes = [NSAttributedStringKey.font : UIFont(name: "Raleway-Semibold", size: 14)!,
                               NSAttributedStringKey.strokeColor : FoodieGlobal.Constants.TextColor]
    navigationItem.rightBarButtonItem!.setTitleTextAttributes(titleTextAttributes, for: .normal)
    navigationItem.rightBarButtonItem!.tintColor = FoodieGlobal.Constants.ThemeColor
    
    // Update the appearance
    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedStringKey.font.rawValue : UIFont(name: "Raleway-Regular", size: 14)!, NSAttributedStringKey.strokeColor.rawValue : FoodieGlobal.Constants.TextColor]
    categorySearchBar.delegate = self
    
    // Create and configure the Tree View
    categoryTreeView.register(UINib.init(nibName: String(describing: CategoryTableViewCell.self), bundle: nil), forCellReuseIdentifier: Constants.categoryCellReuseIdentifier)
    categoryTreeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    categoryTreeView.backgroundColor = .white
    categoryTreeView.clipsToBounds = true
    categoryTreeView.delegate = self
    categoryTreeView.dataSource = self
    categoryTreeView.scrollView.delegate = self
    categoryTreeView.treeFooterView = UIView()
    categoryTreeView.rowHeight = Constants.categoryTreeViewRowHeight
    //categoryTreeView.allowsSelection = false
    
    view.insertSubview(categoryTreeView, aboveSubview: backgroundView)
    view.insertSubview(stackView, aboveSubview: categoryTreeView)
  }
  

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Update the rest of the UI
    if let suggestedCategoryName = suggestedCategory?.name {
      categorySearchBar.text = suggestedCategoryName
      categoryName = suggestedCategoryName
      if categoryArray != nil {
        search()
      }
    }
    
    // Make the Search bar become first responder
    categorySearchBar.becomeFirstResponder()
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    categorySearchBar.resignFirstResponder()
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    if let delegate = delegate {
      // Compute what is the actually selected categories and pass that back to the delegate
      var selectedCategories = [FoodieCategory]()
      
      for category in categoryArray {
        if category.selected == .selected {
          selectedCategories.append(category)
        }
      }
      delegate.categorySearchComplete(categories: selectedCategories)
    }
  }
  
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    categoryTreeView.scrollView.contentInset = UIEdgeInsetsMake(stackView.bounds.height, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }
  
}


// MARK: - Search Bar Delegate Protocol Conformance
extension CategoryViewController: UISearchBarDelegate {
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === categorySearchBar {
      if searchText == "" {
        categoryName = nil
        categoryTreeView.reloadData()
      } else {
        categoryName = searchText
        search()
      }
    }
  }
}



// MARK: - Table View Data Source Protocol Conformance
extension CategoryViewController: RATreeViewDataSource {
  
  func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
    
    if let category = item as? FoodieCategory {
      if let subcategories = category.subcategories {
        return subcategories.count
      } else {
        return 0
      }
    }
    
    // Responding depending on whether user have typed in anything
    else if categoryName != nil {
      
      // Show filtered list if no item supplied
      if let categoryResultArray = categoryResultArray {
        return categoryResultArray.count
      } else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("categoryResultArray is nil")
        }
        return 0
      }
      
    } else {
      
      // Show stock tree if no item supplied
      return FoodieCategory.tree.count
    }
  }
  
  
  func treeView(_ treeView: RATreeView, child index: Int, ofItem item: Any?) -> Any {
    
    // Item coming in is a FoodieCategory. RATreeView will only do this if there are subcategories to return
    if let category = item as? FoodieCategory  {
      guard let subcategories = category.subcategories else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Item supplied by treeView(_: child: ofItem:) does not contain subcategories")
        }
        return UITableViewCell()
      }
      if index >= subcategories.count {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Index supplied by treeView(_: child: ofItem:) is out of range in subcategory array")
        }
        return UITableViewCell()
      }
      return subcategories[index]
    }
    
    // Item coming in is a not a FoodieCategory. So assume RATreeView is asking for items for the root Tree array
    else if categoryName != nil {
      guard let categoryResultArray = categoryResultArray else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("categoryResultArray nil when showFilteredCateogires = true")
        }
        return UITableViewCell()
      }
      if index >= categoryResultArray.count {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Index supplied by treeView(_: child: ofItem:) is out of range in categoryResultArray")
        }
        return UITableViewCell()
      }
      return categoryResultArray[index]
    }
     
    // Only thing left is the unfiltered root Tree straight from FoodieCategory class
    else {
      if index >= FoodieCategory.tree.count {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Index supplied by treeView(_: child: ofItem:) is out of range in FoodieCategory.tree")
        }
        return UITableViewCell()
      }
      return FoodieCategory.tree[index]
    }
  }
  
  
  func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
    
    guard let cell = treeView.dequeueReusableCell(withIdentifier: Constants.categoryCellReuseIdentifier) as? CategoryTableViewCell else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("TreeView dequeued nil or non-CategoryTableViewCell")
      }
      return UITableViewCell()  // Return some new cell to prevent crashing
    }
    
    guard let category = item as? FoodieCategory, let categoryName = category.name else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Item supplied by treeView(_: cellforItem:) is nil, not a FoodieCategory or contains no category name")
      }
      return UITableViewCell()
    }
    
    // Determine how the expanding arrow button should look like
    if let subcategories = category.subcategories, subcategories.count != 0 {
      cell.expandButton.isHidden = false
      
      if treeView.isCell(forItemExpanded: item!) {
        cell.set(to: .expand, animated: false)
      } else {
        cell.set(to: .collapse, animated: false)
      }
    } else {
      cell.expandButton.isHidden = true
    }
    
    // Title Text
    cell.titleLabel.text = categoryName
    
    // Check Box
    cell.setRadio(to: category.selected)
    
    // Cell view background color
    cell.backgroundColor = UIColor(white: 1.0 - 0.025*CGFloat(category.catLevel - 1), alpha: 1.0)  // So Level 1 is 1.0, Level 2 is 0.975, etc
    
    cell.delegate = self
    cell.categoryItem = category
    cell.selectionStyle = .none
    return cell
  }
  
  func treeView(_ treeView: RATreeView, canEditRowForItem item: Any) -> Bool {
    return false
  }
}


// MARK: - Table View Delegate Protocol Conformance
extension CategoryViewController: RATreeViewDelegate {
  func treeView(_ treeView: RATreeView, didSelectRowForItem item: Any) {
    guard let cell = treeView.cell(forItem: item) as? CategoryTableViewCell else {
      CCLog.assert("Expected cell for item")
      return
    }
    cell.expandButtonAction(cell.expandButton)
  }
  
  func treeView(_ treeView: RATreeView, shouldExpandRowForItem item: Any) -> Bool {
    return false
  }
  
  func treeView(_ treeView: RATreeView, shouldCollapaseRowForItem item: Any) -> Bool {
    return false
  }
}



// MARK: - Category Table View Cell Delegate Protocl Conformance
extension CategoryViewController: CategoryTableViewCellDelegate {
  func expandCollpase(for cell: CategoryTableViewCell, to state: CategoryTableViewCell.ExpandCollapseState) {
    
    guard let category = cell.categoryItem else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("categoryItem does not contain a FoodieCategory and is nil")
      }
      return
    }
    
    switch state {
    case .expand:
      categoryTreeView.expandRow(forItem: category)
    case .collapse:
      categoryTreeView.collapseRow(forItem: category)
    }
  }
  
  func selection(for cell: CategoryTableViewCell, to state: FoodieCategory.SelectionState) {
    guard let cellCategory = cell.categoryItem else {
      CCLog.assert("Cell with no Category Associated")
      return
    }
    cellCategory.setSelectionRecursive(to: state)
    
    if let visibleCells = categoryTreeView.visibleCells() as? [CategoryTableViewCell] {
      for visibleCell in visibleCells {
        guard let visibleCategory = visibleCell.categoryItem else {
          CCLog.fatal("visibleCategoryItem does not contain a FoodieCategory and is nil")
        }
        let selectionState = visibleCategory.selected
        visibleCell.setRadio(to: selectionState)
      }
    }
  }
}



// MARK: - Scroll View Delegate Protocol Conformance
extension CategoryViewController: UIScrollViewDelegate {
  // Hide the keyboard if the category table begins dragging
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    categorySearchBar.resignFirstResponder()
  }
}


