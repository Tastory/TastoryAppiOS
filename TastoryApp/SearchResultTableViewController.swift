//
//  SearchResultTableViewController.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-27.
//  Copyright © 2018 Tastry. All rights reserved.
//

import Foundation
import UIKit

class SearchResultTableViewController: UIViewController {

  struct DisplayCell: Hashable {
    var hashValue: Int {
      return title.hashValue ^ detail.hashValue
    }

    init(title: String, detail: String) {
      self.title = title
      self.detail = detail
    }

    static func ==(lhs: SearchResultTableViewController.DisplayCell, rhs: SearchResultTableViewController.DisplayCell) -> Bool {
      if lhs.title == rhs.title && lhs.detail == rhs.detail {
        return true
      }
      return false
    }

    var title: String = ""
    var detail: String = ""
  }

  private struct Constants {
    static let resultTreeViewRowHeight: CGFloat = 60.0
  }
  
  // MARK: - Private Instance Variables
  private var resultsData = [SearchResult]()
  private var displayCellSet: Set<DisplayCell> = Set() // keep track of titles of each cell to avoid duplicate entries

  // MARK: - Public Instance Variables
  public var displayDelegate: SearchResultDisplayDelegate?
  public var universalSearchDelegate: UniversalSearchDelegate?

  // MARK: - IBOutlets
  @IBOutlet weak var resultTableView: UITableView!

  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    resultTableView.dataSource = self
    resultTableView.delegate = self
    resultTableView.tableFooterView = UIView()
    resultTableView.rowHeight = Constants.resultTreeViewRowHeight

    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)

  }

  // MARL: - Private Instance Functions
  @objc private func keyboardWillShow(_ notification: NSNotification) {
    if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
      resultTableView.contentInset.bottom = keyboardSize.height
    }
  }

  @objc private func keyboardWillHide(_ notification: NSNotification) {
    resultTableView.contentInset.bottom = 0
  }

  private func switchVenue(result: SearchResult) {
    // if it is venue then we need to make sure that the venue from our database gets priority
    // by switching out the venue object
    if result.cellType == .venue {

      guard let sourceVenue = result.venue else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("the venue is nil")
        }
        return
      }

      if sourceVenue.objectId == nil {
        // no replacement needed as this entry itself is generated on the fly from foursquare
        return
      }

      // find the existing venue entry
      var i = 0
      for data in self.resultsData {
        if data.cellType == .venue {
          guard let targetVenue = data.venue else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.assert("the venue is nil")
            }
            return
          }

          if targetVenue.foursquareVenueID == sourceVenue.foursquareVenueID {
            self.resultsData[i].venue = sourceVenue
          }
        }
        i = i + 1
      }
    }
  }

  // MARK: - Public Instance Functions
  public func clearTable() {
    DispatchQueue.main.async {
      self.resultsData.removeAll()
      self.displayCellSet.removeAll()
      self.resultTableView.reloadData()
    }
  }
  public func insertByDistance(results: [SearchResult]) {
    DispatchQueue.main.async {
      for result in results {
        var i = 0

        for data in self.resultsData {
          if result.venueDistance >= data.venueDistance {
            i = i + 1
          }
        }
        let cell = DisplayCell(title: result.title.string,detail: result.detail.string)
        if self.displayCellSet.contains(cell) {
          self.switchVenue(result: result)
          // skip entry as the title of this entry already existed
          continue
        }

        self.displayCellSet.insert(cell)
        self.resultsData.insert(result, at: i)
      }
      self.resultTableView.reloadData()
    }
  }

  public func pushFront(results: [SearchResult]) {
    DispatchQueue.main.async {
      let isInsert = (self.resultsData.count != 0)
      var insertedIdx: [IndexPath] = []
      var i = 0
      for result in results {

        let cell = DisplayCell(title: result.title.string,detail: result.detail.string)
        if self.displayCellSet.contains(cell) {
          self.switchVenue(result: result)
          // skip entry as the title of this entry already existed
          continue
        }

        self.displayCellSet.insert(cell)
        self.resultsData.insert(result, at: 0)
        insertedIdx.append(IndexPath(row: i, section: 0))
        i = i + 1
      }

      if isInsert {
        self.resultTableView.insertRows(at: insertedIdx, with: .automatic)
      } else {
        self.resultTableView.reloadData()
      }
    }
  }

  public func push(results: [SearchResult]) {
    DispatchQueue.main.async  {
      let isInsert = (self.resultsData.count != 0)

      var insertedIdx: [IndexPath] = []
      var i = self.resultsData.count
      for result in results {

        let cell = DisplayCell(title: result.title.string,detail: result.detail.string)
        if self.displayCellSet.contains(cell) {
          self.switchVenue(result: result)
          // skip entry as the title of this entry already existed
          continue
        }

        self.displayCellSet.insert(cell)
        self.resultsData.append(result)
        insertedIdx.append(IndexPath(row: i, section: 0))
        i = i + 1
      }

      if isInsert  {
        self.resultTableView.insertRows(at: insertedIdx, with: .automatic)
      } else {
        self.resultTableView.reloadData()
      }
    }
  }

}

extension SearchResultTableViewController: UITableViewDataSource {

  func numberOfSections(in tableView: UITableView) -> Int {
    return 1  // Hard coded to 1 for now?
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return resultsData.count
  }


  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = resultTableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("TableView dequeued nil or non-SearchResultCell")
      }
      return UITableViewCell()  // Return some new cell to prevent crashing
    }

    // used for earl grey testing
    cell.accessibilityLabel = "searchResultCell"
    cell.accessibilityTraits = UIAccessibilityTraitButton
    cell.isAccessibilityElement = true
    cell.isUserInteractionEnabled = true

    // clear cell
    cell.title.text = ""
    cell.detail.text = ""

    let dataCell = resultsData[indexPath.row]

    // display the correct info based on the different results
    cell.title.attributedText = dataCell.title
    cell.detail.attributedText = dataCell.detail
    cell.icon.image = UIImage(named:dataCell.iconName)

    return cell
  }

  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    self.universalSearchDelegate?.dismissKeyboard()
  }
}

extension SearchResultTableViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    if indexPath.row < resultsData.count {
      let result = resultsData[indexPath.row]

      guard let keyword = universalSearchDelegate?.getSearchKeyWord() else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Failed to get keyword from search which is impossible since you already got result")
        }
        return
      }
      // add delay for showing content
      UIApplication.shared.beginIgnoringInteractionEvents()
      DispatchQueue.main.asyncAfter(deadline: .now() + FoodieGlobal.Constants.DefaultDeepLinkWaitDelay) {
        UIApplication.shared.endIgnoringInteractionEvents()
        self.displayDelegate?.showSearchResult(result: result, keyword: keyword)
        self.universalSearchDelegate?.dismissUniveralSearch()
      }
    } else {
      // this case is possible when the table is being cleared while the user is selecting an item in the table
      CCLog.warning("The selected index is outside the table view's data array")
    }
  }
}
