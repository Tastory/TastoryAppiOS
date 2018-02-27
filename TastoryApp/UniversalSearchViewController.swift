//
//  UniversalSearchViewController.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-23.
//  Copyright © 2018 Tastry. All rights reserved.
//

import UIKit
import Parse
import MapKit

protocol SearchResultDisplayDelegate: class {
  func display(story: FoodieStory)
  func display(user: FoodieUser)
  func display(venue: FoodieVenue)
  func applyFilter(meal: MealType)
  func applyFilter(category: FoodieCategory)
}
class UniversalSearchViewController: OverlayViewController {

  struct SearchResult {
    // MARK: - Constants/Enums
    enum resultType {
      case venue
      case category
      case location
      case story
      case user
      case meal
    }

    // MARK: - public Variables
    public var cellType: resultType?
    public var user: FoodieUser?
    public var venue: FoodieVenue?
    public var story: FoodieStory?
    public var category: FoodieCategory?
    public var meal: MealType?

    public var title: String = ""
    public var detail: String = ""
    public var iconName: String = ""
  }

  private struct Constants {
    static let SearchBarSearchDelay = 0.75
    static let resultTreeViewRowHeight: CGFloat = 60.0
  }

  // MARK: - Private Instance Functions
  private var searchResults = [MKLocalSearchCompletion]()
  private var resultsData = [SearchResult]()
  private var titleSet: Set<String> = Set() // keep track of titles of each cell to avoid duplicate entries
  private var searchKeyWord = ""

  // MARK: - Public Instance Functions
  var delegate: SearchResultDisplayDelegate?

  // MARK: - IBOutlets
  @IBOutlet weak var resultTableView: UITableView!
  @IBOutlet weak var searchBar: UISearchBar!

  // MARK: - IBActions
  @IBAction func cancelAction(_ sender: UIButton) {
    popDismiss(animated: true)
  }

  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    resultTableView.dataSource = self
    resultTableView.delegate = self
    resultTableView.tableFooterView = UIView()
    resultTableView.rowHeight = Constants.resultTreeViewRowHeight

    searchBar.delegate = self
  }

  // MARK: - Private Instance Functions
  private func pushFront(results: [SearchResult]) {
    DispatchQueue.main.async {
      CCLog.verbose("before push tableResults.count:\(self.resultsData.count)")
      let isInsert = (self.resultsData.count != 0)
      var insertedIdx: [IndexPath] = []
      var i = 0
      for result in results {
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

  private func push(results: [SearchResult]) {
    DispatchQueue.main.async  {
      CCLog.verbose("before push tableResults.count:\(self.resultsData.count)")
      let isInsert = (self.resultsData.count != 0)

      var insertedIdx: [IndexPath] = []
      var i = self.resultsData.count
      for result in results {
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

  @objc func search() {

    DispatchQueue.main.async {
      self.resultsData.removeAll()
      self.titleSet.removeAll()
      self.resultTableView.reloadData()
    }

    if searchKeyWord != "" {

      let localComplete = MKLocalSearchCompleter.init()
      localComplete.delegate = self
      localComplete.filterType = .locationsOnly
      localComplete.queryFragment = searchKeyWord


      // search meal type
      let mealMatches:[MealType] = MealType.types.filter { (mealType) -> Bool in
        return mealType.rawValue.localizedCaseInsensitiveContains(searchKeyWord)
      }

      if mealMatches.count > 0  {
        // limit 2 matches
        var i = 0
        var results:[SearchResult] = []
        for meal in mealMatches {

          if titleSet.contains(meal.rawValue) {
            // skip entry as the title of this entry already existed
            continue
          }

          var result = SearchResult()
          result.title = meal.rawValue
          result.cellType = .meal
          result.meal = meal
          result.iconName = "Entry-Meal"

          titleSet.insert(meal.rawValue)
          results.append(result)
          i = i + 1
          if( i > 2) {
            break
          }
        }
        pushFront(results: results)
      }

      // search category
      let categoryMatches:[String:FoodieCategory] = FoodieCategory.list.filter { (key, category) -> Bool in
        guard let name = category.name else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("An error occured when getting category name")
          }
          return false
        }
        return name.localizedCaseInsensitiveContains(searchKeyWord)
      }

      if categoryMatches.count > 0 {
        // limit 2 matches
        var i = 0
        var results:[SearchResult] = []
        for category in categoryMatches {

          guard let categoryName = category.value.name else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.fatal("Category name is nil")
            }
            return
          }

          if titleSet.contains(categoryName) {
            // skip entry as the title of this entry already existed
            continue
          }

          var result = SearchResult()
          result.cellType = .category
          result.category = category.value
          result.title = categoryName

          titleSet.insert(categoryName)
          results.append(result)

          i = i + 1
          if( i > 2) {
            break
          }
        }
        pushFront(results: results)
      }

      // Setup parameters and submit Cloud function
      var parameters = [AnyHashable: Any]()
      parameters["keywords"] = searchKeyWord

      PFCloud.callFunction(inBackground: "universalSearch" , withParameters: parameters) { (objects, error) in
        if error != nil {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.fatal("Error occured when calling universal search: \(error!.localizedDescription)")
          }
          return
        }

        if let pfobjs = objects as? [PFObject] {
          var results:[SearchResult] = []

          for obj in pfobjs {

            var result = SearchResult()

            if obj is FoodieStory, let story = obj as? FoodieStory {
              result.cellType = .story

              guard let title = story.title else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("Title is missing from FoodieStory")
                }
                return
              }

              if self.titleSet.contains(title) {
                // skip entry as the title of this entry already existed
                continue
              }

              guard let user = story.author else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("Author is missing from FoodieStory")
                }
                return
              }

              guard let venue = story.venue else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("FoodieVenue is nil")
                }
                return
              }

              // fetch the pfobject pointers
              do {
                try user.fetchIfNeeded()
                try venue.fetchIfNeeded()
              } catch {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("An error occurred when fetching user and venue")
                }
                return
              }

              guard let userName = user.username else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("UserName is missing from FoodieUser")
                }
                return
              }

              guard let venueName = venue.name else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("name is missing from FoodieVenue")
                }
                return
              }

              result.title = title
              result.detail = venueName + " " + userName
              result.iconName = "Entry-StoryTitle"
              result.story = story

              self.titleSet.insert(title)
              results.append(result)
            } else if obj is FoodieUser, let user = obj as? FoodieUser {

              guard let userName = user.username else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("user's fullname is nil")
                }
                return
              }

              // full name could be null
              if let fullName = user.fullName {
                result.title = fullName
              } else {
                result.title = userName
              }

              if self.titleSet.contains(result.title) {
                // skip entry as the title of this entry already existed
                continue
              }

              result.detail = "@" + userName
              result.iconName = "Discover-ProfileButton"
              result.cellType = .user
              result.user = user

              self.titleSet.insert(result.title)
              results.append(result)
            } else if obj is FoodieVenue, let venue = obj as? FoodieVenue {

              guard let venueName = venue.name else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("venueName is nil")
                }
                return
              }

              if self.titleSet.contains(venueName) {
                // skip entry as the title of this entry already existed
                continue
              }

              if let address = venue.streetAddress {
                result.detail = address
              }

              result.title = venueName
              result.iconName = "Entry-Venue"
              result.cellType = .venue
              result.venue = venue

              self.titleSet.insert(venueName)
              results.append(result)
            } else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("Error occured when converting foodie types")
              }
            }
          }
          self.push(results: results)
        }
      }
    }
  }
}

extension UniversalSearchViewController: MKLocalSearchCompleterDelegate {

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    searchResults = completer.results
    //searchResultsTableView.reloadData()
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    // handle error
  }
}

extension UniversalSearchViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let result = resultsData[indexPath.row]
    guard let type = result.cellType else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("CellType is nil from result")
      }
      return
    }

    switch type {
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

extension UniversalSearchViewController: UITableViewDataSource {

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
    cell.title.text = dataCell.title
    cell.detail.text = dataCell.detail
    cell.icon.image = UIImage(named:dataCell.iconName)

    return cell
  }
}

// MARK: - Search Bar Delegate Protocol Conformance
extension UniversalSearchViewController: UISearchBarDelegate {

  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    searchKeyWord = searchText
    NSObject.cancelPreviousPerformRequests(withTarget: #selector(search))
    self.perform(#selector(search), with: nil, afterDelay: Constants.SearchBarSearchDelay)
  }

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    searchBar.resignFirstResponder()
  }
}

