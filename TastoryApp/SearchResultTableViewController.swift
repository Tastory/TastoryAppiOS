//
//  SearchResultTableViewController.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-27.
//  Copyright © 2018 Tastry. All rights reserved.
//

import Foundation
import UIKit


protocol SearchResultDisplayDelegate: class {
  func display(story: FoodieStory)
  func display(user: FoodieUser)
  func display(venue: FoodieVenue)
  func applyFilter(meal: MealType)
  func applyFilter(category: FoodieCategory)
  func applyFilter(location: String)
}

class SearchResultTableViewController: UIViewController {

  private struct Constants {
    static let resultTreeViewRowHeight: CGFloat = 60.0
  }
  
  // MARK: - Private Instance Variables
  private var resultsData = [SearchResult]()
  private var titleSet: Set<String> = Set() // keep track of titles of each cell to avoid duplicate entries

  // MARK: - Public Instance Variables
  public var delegate: SearchResultDisplayDelegate?

  // MARK: - IBOutlets
  @IBOutlet weak var resultTableView: UITableView!

  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    resultTableView.dataSource = self
    resultTableView.delegate = self
    resultTableView.tableFooterView = UIView()
    resultTableView.rowHeight = Constants.resultTreeViewRowHeight
    // fix scrolling problem when item is right at the bottom edge of the screen
    resultTableView.contentInset = UIEdgeInsetsMake(self.topLayoutGuide.length, 0, 200, 0)
  }

  // MARK: - Public Instance Functions
  public func clearTable() {
    DispatchQueue.main.async {
      self.resultsData.removeAll()
      self.titleSet.removeAll()
      self.resultTableView.reloadData()
    }
  }

  public func pushFront(results: [SearchResult]) {
    DispatchQueue.main.async {
      CCLog.verbose("before push tableResults.count:\(self.resultsData.count)")
      let isInsert = (self.resultsData.count != 0)
      var insertedIdx: [IndexPath] = []
      var i = 0
      for result in results {

        if self.titleSet.contains(result.title.string) {
          // skip entry as the title of this entry already existed
          continue
        }

        self.titleSet.insert(result.title.string)
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
      CCLog.verbose("before push tableResults.count:\(self.resultsData.count)")
      let isInsert = (self.resultsData.count != 0)

      var insertedIdx: [IndexPath] = []
      var i = self.resultsData.count
      for result in results {

        if self.titleSet.contains(result.title.string) {
          // skip entry as the title of this entry already existed
          
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
              continue
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
          continue
        }

        self.titleSet.insert(result.title.string)
        self.resultsData.append(result)
        insertedIdx.append(IndexPath(row: i, section: 0))
        i = i + 1
      }

      CCLog.verbose("after append tableResults.count:\(self.resultsData.count)")
      CCLog.verbose("number of indices inserted: \(insertedIdx.count)")

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
}

extension SearchResultTableViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let result = resultsData[indexPath.row]
    guard let type = result.cellType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("CellType is nil from result")
      }
      return
    }

    switch type {

    case .location:

      var location = result.title.string
      if !result.detail.string.isEmpty {
        location = location +  ", " + result.detail.string
      }
      delegate?.applyFilter(location: location)

      break
    case .category:
      guard let category = result.category else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Category is nil")
        }
        return
      }
      delegate?.applyFilter(category: category)
      break

    case .meal:
      guard let meal = result.meal else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Meal is nil")
        }
        return
      }
      delegate?.applyFilter(meal: meal)
      break

    case .story:
      guard let story = result.story else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Story is nil")
        }
        return
      }
      delegate?.display(story: story)
      break

    case .user:
      guard let user = result.user else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("User is nil")
        }
        return
      }

      delegate?.display(user: user)
      break

    case .venue:

      guard let venue = result.venue else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("Venue is nil")
        }
        return
      }

      delegate?.display(venue: venue)
      break

    default:
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Unknown cell type")
      }
      break
    }
  }
}
