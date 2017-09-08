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
  func categorySearchComplete(category: FoodieCategory)
  
  // 2. Lets make selecting a category actually pass the category back to the JournalEntryVC
  // 3. Lets make it so one can pass in a FoodieCategory as a suggested Category and auto initiate a search
}


class CategoryTableViewController: UIViewController {

  // MARK: - Constants
  struct Constants {
    fileprivate static let categoryCellReuseIdentifier = "CategoryCell"
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
    dismiss(animated: true, completion: nil)
  }

  
  
  // MARK: - Private Instance Functions
  func search() {

    var categorySearchTerm = ""
    if let categoryName = categoryName {
      categorySearchTerm = categoryName
    }
    
    categoryResultArray = categoryArray.filter { category in
      
      guard let categoryName = category.name else {
        
        if let id = category.foursquareCategoryID {
          CCLog.assert("Category with ID \(id) has no name. Filtering out categories with no name")
        } else {
          CCLog.fatal("Category doesn't even have ID!!!")
        }
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
        return false  // Don't return categories with no name
      }
      
      return categoryName.localizedCaseInsensitiveContains(categorySearchTerm)
    }
    
    // Sort by seeing if the First Category should be placed ahead of the Second
    categoryResultArray!.sort { (firstCategory, secondCategory) -> Bool in
      
      // Sort by lower level first
      if firstCategory.catLevel > secondCategory.catLevel {
        return true
      
      // What if the levels are the same?
      } else if firstCategory.catLevel == secondCategory.catLevel {
        
        guard let firstCategoryName = firstCategory.name, let secondCategoryName = secondCategory.name else {
          if let firstID = firstCategory.foursquareCategoryID, let secondID = secondCategory.foursquareCategoryID {
            CCLog.assert("At least one category has no name! ID \(firstID) & \(secondID) respectively. Cannot do String comparison")
          } else {
            CCLog.fatal("At least one category doesn't even have an ID!!!")
          }
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
          
          if firstCategory.name == nil {
            return false  // return the nameless category last
          } else {
            return true
          }
        }
        
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
    categoryTreeView.reloadData()
  }
  
  
  
  // MARK: - Public Instance Functions
  
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // This might be computationally intensive. Do it first and in the background?
    DispatchQueue.global(qos: .userInitiated).async {
      self.categoryArray = FoodieCategory.list.map { return $0.value }
    }
    
    // I'd say create the Tree View next
    categoryTreeView = RATreeView(frame: view.bounds)
    categoryTreeView.register(UINib.init(nibName: String(describing: CategoryTableViewCell.self), bundle: nil), forCellReuseIdentifier: Constants.categoryCellReuseIdentifier)
    categoryTreeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    //categoryTreeView.delegate = self
    categoryTreeView.dataSource = self
    categoryTreeView.scrollView.delegate = self
    categoryTreeView.treeFooterView = UIView()
    categoryTreeView.backgroundColor = .clear
    view.addSubview(categoryTreeView)
    
    view.bringSubview(toFront: stackView)
    categorySearchBar.delegate = self
    
    // Update the rest of the UI
    if let suggestedCategoryName = suggestedCategory?.name {
      categorySearchBar.text = suggestedCategoryName
      categoryName = suggestedCategoryName
    }
  }
  
  
  override func viewDidLayoutSubviews() {
    categoryTreeView.scrollView.contentInset = UIEdgeInsetsMake(stackView.bounds.height, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("JournalViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Search Bar Delegate Protocol Conformance
extension CategoryTableViewController: UISearchBarDelegate {
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === categorySearchBar {
      categoryName = searchText
      search()
    }
  }
  
  
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if searchBar === categorySearchBar { search() }
  }
}



// MARK: - Table View Data Source Protocol Conformance
extension CategoryTableViewController: RATreeViewDataSource {
  
  func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
    if let category = item as? FoodieCategory, let subcategories = category.subcategories {
      return subcategories.count
    } else {
      return 0
    }
  }
  
  
  func treeView(_ treeView: RATreeView, child index: Int, ofItem item: Any?) -> Any {
    guard let categoryResultArray = categoryResultArray else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("categoryResultArray = nil")
      }
      sleep(100)
      fatalError()  // Need to add this to stop the compiler from complaining
    }
    
    return categoryResultArray[index] as Any
  }
  
  
  func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
    
    guard let cell = treeView.dequeueReusableCell(withIdentifier: Constants.categoryCellReuseIdentifier) as? CategoryTableViewCell else {
      CCLog.assert("TreeView dequeued nil or non-CategoryTableViewCell")
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
      return UITableViewCell()  // Return some new cell to prevent crashing
    }
    
    guard let category = item as? FoodieCategory, let categoryName = category.name else {
      CCLog.assert("Item supplied by treeView(_: cellforItem:) is nil, not a FoodieCategory or contains no category name")
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain)
      return UITableViewCell()
    }
    
    cell.titleLabel?.text = categoryName
    return cell
  }
}


// MARK: - Table View Delegate Protocol Conformance
//extension CategoryTableViewController: RATreeViewDelegate {
////  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
////    guard let categoryResultArray = categoryResultArray else {
////      CCLog.assert("categoryResultArray = nil not expected when user didSelectRowAt \(indexPath.row)")
////      internalErrorDialog()
////      return
////    }
////    
////    // Call the delegate's function for returning the category
////    delegate?.categorySearchComplete(category: categoryResultArray[indexPath.row])
////    dismiss(animated: true, completion: nil)
////  }
//}


// MARK: - Scroll View Delegate Protocol Conformance
extension CategoryTableViewController: UIScrollViewDelegate {
  // Hide the keyboard if the category table begins dragging
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    categorySearchBar?.resignFirstResponder()
  }
}


