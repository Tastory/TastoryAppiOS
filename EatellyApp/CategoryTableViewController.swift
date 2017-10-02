//
//  CategoryTableViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-12.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit
import RATreeView


protocol CategoryTableReturnDelegate {
  func categorySearchComplete(category: FoodieCategory?)
  
  // 2. Lets make selecting a category actually pass the category back to the StoryEntryVC
  // 3. Lets make it so one can pass in a FoodieCategory as a suggested Category and auto initiate a search
}


class CategoryTableViewController: UIViewController {

  // MARK: - Constants
  struct Constants {
    fileprivate static let categoryCellReuseIdentifier = "CategoryCell"
    fileprivate static let categoryTreeViewRowHeight: CGFloat = 50.0
    fileprivate static let categoryIconLeadingConstant: CGFloat = 16
  }
  
  
  
  // MARK: - Public Instance Variables
  var delegate: CategoryTableReturnDelegate?
  var suggestedCategory: FoodieCategory?
  
  
  
  // MARK: - Private Instance Variables
  fileprivate var categoryName: String?
  fileprivate var categoryArray: [FoodieCategory]!  // Intentionally implicitly unwrap so will crash if accessed before viewDidLoad
  fileprivate var categoryResultArray: [FoodieCategory]?
  fileprivate var categoryTreeView: RATreeView!  // Intentional implicitly unwrap so will crash if accessed before viewDidLoad
  
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var stackView: UIStackView!  // TODO: Review whether IBOutlets should be Optional or Forced Unwrapped
  @IBOutlet weak var categorySearchBar: UISearchBar!
  
  
  
  // MARK: - IBActions
  @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
    guard let searchText = categorySearchBar.text, searchText != "" else {
      delegate?.categorySearchComplete(category: nil)
      dismiss(animated: true, completion: nil)
      return
    }
    dismiss(animated: true, completion: nil)
  }

  
  
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
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
        else if firstCategory.catLevel > secondCategory.catLevel {
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
    
    // Create and configure the Tree View
    categoryTreeView = RATreeView(frame: view.bounds)
    categoryTreeView.register(UINib.init(nibName: String(describing: CategoryTableViewCell.self), bundle: nil), forCellReuseIdentifier: Constants.categoryCellReuseIdentifier)
    categoryTreeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    categoryTreeView.delegate = self
    categoryTreeView.dataSource = self
    categoryTreeView.scrollView.delegate = self
    categoryTreeView.treeFooterView = UIView()
    categoryTreeView.backgroundColor = .clear
    categoryTreeView.rowHeight = Constants.categoryTreeViewRowHeight
    categorySearchBar.delegate = self
    
    view.addSubview(categoryTreeView)
    view.bringSubview(toFront: stackView)
  }
  

  override func viewWillAppear(_ animated: Bool) {
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
    categorySearchBar.resignFirstResponder()
  }
  
  
  override func viewDidLayoutSubviews() {
    categoryTreeView.scrollView.contentInset = UIEdgeInsetsMake(stackView.bounds.height, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}


// MARK: - Search Bar Delegate Protocol Conformance
extension CategoryTableViewController: UISearchBarDelegate {
  
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
  
  
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if searchBar === categorySearchBar { search() }
  }
}



// MARK: - Table View Data Source Protocol Conformance
extension CategoryTableViewController: RATreeViewDataSource {
  
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
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("Item supplied by treeView(_: child: ofItem:) does not contain subcategories")
        }
        return UITableViewCell()
      }
      if index >= subcategories.count {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("Index supplied by treeView(_: child: ofItem:) is out of range in subcategory array")
        }
        return UITableViewCell()
      }
      return subcategories[index]
    }
    
    // Item coming in is a not a FoodieCategory. So assume RATreeView is asking for items for the root Tree array
    else if categoryName != nil {
      guard let categoryResultArray = categoryResultArray else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("categoryResultArray nil when showFilteredCateogires = true")
        }
        return UITableViewCell()
      }
      if index >= categoryResultArray.count {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("Index supplied by treeView(_: child: ofItem:) is out of range in categoryResultArray")
        }
        return UITableViewCell()
      }
      return categoryResultArray[index]
    }
     
    // Only thing left is the unfiltered root Tree straight from FoodieCategory class
    else {
      if index >= FoodieCategory.tree.count {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("Index supplied by treeView(_: child: ofItem:) is out of range in FoodieCategory.tree")
        }
        return UITableViewCell()
      }
      return FoodieCategory.tree[index]
    }
  }
  
  
  func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
    
    guard let cell = treeView.dequeueReusableCell(withIdentifier: Constants.categoryCellReuseIdentifier) as? CategoryTableViewCell else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("TreeView dequeued nil or non-CategoryTableViewCell")
      }
      return UITableViewCell()  // Return some new cell to prevent crashing
    }
    
    guard let category = item as? FoodieCategory, let categoryName = category.name else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Item supplied by treeView(_: cellforItem:) is nil, not a FoodieCategory or contains no category name")
      }
      return UITableViewCell()
    }
    
    cell.titleLabel?.text = categoryName
    cell.iconLeadingConstraint?.constant = Constants.categoryIconLeadingConstant * CGFloat(treeView.levelForCell(forItem: category) + 1)
    
    if let subcategories = category.subcategories, subcategories.count != 0 {
      cell.expandButton.isHidden = false
    } else {
      cell.expandButton.isHidden = true
    }
    
    cell.delegate = self
    cell.categoryItem = category
    return cell
  }
}


// MARK: - Table View Delegate Protocol Conformance
extension CategoryTableViewController: RATreeViewDelegate {
  func treeView(_ treeView: RATreeView, didSelectRowForItem item: Any) {
    CCLog.verbose("treeView(didSelectRowForItem:")
    
    guard let category = item as? FoodieCategory else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("categoryItem does not contain a FoodieCategory and is nil")
        self.dismiss(animated: true, completion: nil)
      }
      return
    }
    delegate?.categorySearchComplete(category: category)
    dismiss(animated: true, completion: nil)
  }
  
  func treeView(_ treeView: RATreeView, shouldExpandRowForItem item: Any) -> Bool {
    return false
  }
  
  func treeView(_ treeView: RATreeView, shouldCollapaseRowForItem item: Any) -> Bool {
    return false
  }
}



// MARK: - Category Table View Cell Delegate Protocl Conformance
extension CategoryTableViewController: CategoryTableViewCellDelegate {
  func expandCollpase(for cell: CategoryTableViewCell, to state: CategoryTableViewCell.ExpandCollapseState) {
    
    guard let category = cell.categoryItem else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
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
}



// MARK: - Scroll View Delegate Protocol Conformance
extension CategoryTableViewController: UIScrollViewDelegate {
  // Hide the keyboard if the category table begins dragging
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    categorySearchBar.resignFirstResponder()
  }
}


