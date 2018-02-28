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

class UniversalSearchViewController: OverlayViewController {

  // MARK: - Constants/Enums
  private struct Constants {
    static let SearchBarSearchDelay = 0.75
  }

  // MARK: - Private Instance Functions
  private var searchKeyWord = ""
  private var resultTableVC: SearchResultTableViewController?


  // MARK: - Public Instance Functions
  var delegate: SearchResultDisplayDelegate?
  var currentLocation: CLLocation?

  // MARK: - IBOutlets
  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var tablePlaceHolder: UIView!
  
  // MARK: - IBActions
  @IBAction func cancelAction(_ sender: UIButton) {
    popDismiss(animated: true)
  }

  // MARK: - Public Instance Functions
  private func highlightSearchTerms(text: String) -> (NSMutableAttributedString, Bool) {
    let index = text.index(of: searchKeyWord)
    let attrText = NSMutableAttributedString()

    if let index = index {
      attrText.normal(String(text[text.startIndex..<index]))
      attrText.bold(searchKeyWord)
      let offsetIdx = text.index(index, offsetBy: searchKeyWord.count)
      attrText.normal(String(text[offsetIdx..<text.endIndex]))
      return (attrText, true)
    } else {
      // didnt find the searchKeyWord
      attrText.normal(text)
      return (attrText, false)
    }
  }

  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    searchBar.delegate = self

    let storyboard = UIStoryboard(name: "Filters", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SearchResultTableViewController") as? SearchResultTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of FiltersNavViewController Class!!")
      }
      return
    }
    resultTableVC = viewController
    viewController.delegate = delegate
    self.addChildViewController(viewController)
    tablePlaceHolder.addSubview(viewController.view)
  }

  @objc func search() {
    guard let resultTableVC = resultTableVC else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Search Result Table View Controller is nil!!")
      }
      return
    }

    resultTableVC.clearTable()

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

          var result = SearchResult()

          let (title, highlighted) = highlightSearchTerms(text: meal.rawValue)

          if !highlighted {
            continue
          }

          result.title = title
          result.cellType = .meal
          result.meal = meal
          result.iconName = "Entry-Meal"
          results.append(result)

          i = i + 1
          if( i > 2) {
            break
          }
        }
        resultTableVC.pushFront(results: results)
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

          let (title, highlighted) = highlightSearchTerms(text: categoryName)
          if !highlighted {
            continue
          }

          var result = SearchResult()
          result.cellType = .category
          result.category = category.value
          result.title = title
          results.append(result)

          i = i + 1
          if( i > 2) {
            break
          }
        }
        resultTableVC.pushFront(results: results)
      }

      // search four square
      guard let location = currentLocation else {
        AlertDialog.present(from: self, title: "Location Error", message: "Obtained invalid location information") { _ in
          CCLog.warning("LocationWatch.get() returned locaiton = nil")
        }
        return
      }

      FoodieVenue.searchFoursquare(for: self.searchKeyWord, at: location){ (venues, geocode, error) in

        if let error = error {
          AlertDialog.standardPresent(from: self, title: .genericLocationError, message: .locationTryAgain)
          CCLog.fatal("An error occured when searching on foursquare - \(error.localizedDescription)")
        }

        guard let venues = venues else {
          AlertDialog.standardPresent(from: self, title: .genericLocationError, message: .locationTryAgain) { _ in
            CCLog.warning("The returned venues array is nil")
          }
          return
        }

        var results:[SearchResult] = []
        var i = 0
        for venue in venues {
          guard let venueName = venue.name else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.fatal("venueName is nil")
            }
            return
          }

          var result = SearchResult()
          var isDetailHighlighted = false
          if let address = venue.streetAddress {
            let (detail, highlightedDetail) = self.highlightSearchTerms(text: address)
            isDetailHighlighted = highlightedDetail
            result.detail = detail
          }

          let (title, highlighted) = self.highlightSearchTerms(text: venueName)
          if !highlighted && !isDetailHighlighted {
            continue
          }

          result.title = title
          result.iconName = "Entry-Venue"
          result.cellType = .venue
          result.venue = venue
          results.append(result)
          // limit 3 results
          i = i + 1
          if( i > 3) {
            break
          }
        }
        resultTableVC.push(results: results)
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

              guard let storyTitle = story.title else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("Title is missing from FoodieStory")
                }
                return
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

              let (title, isTitleHighlighted) = self.highlightSearchTerms(text: storyTitle)
              let (detail, isDetailHighlighted) = self.highlightSearchTerms(text: venueName + " @" + userName)
              if !isTitleHighlighted && !isDetailHighlighted {
                continue
              }

              result.title = title
              result.detail = detail
              result.iconName = "Entry-StoryTitle"
              result.story = story

              results.append(result)
            } else if obj is FoodieUser, let user = obj as? FoodieUser {

              guard let userName = user.username else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("user's fullname is nil")
                }
                return
              }

              // full name could be null
              var titleStr:String
              if let fullName = user.fullName, !fullName.isEmpty {
                titleStr = fullName
              } else {
                titleStr = userName
              }

              let (title, isTitleHighlighted) = self.highlightSearchTerms(text: titleStr)
              let (detail, isDetailHighlighted) = self.highlightSearchTerms(text: "@" + userName)
              if !isTitleHighlighted && !isDetailHighlighted {
                continue
              }

              result.title = title
              result.detail = detail
              result.iconName = "Discover-ProfileButton"
              result.cellType = .user
              result.user = user

              results.append(result)
            } else if obj is FoodieVenue, let venue = obj as? FoodieVenue {

              guard let venueName = venue.name else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("venueName is nil")
                }
                return
              }

              var isDetailHighlighted = false
              if let address = venue.streetAddress {
                let (detail, detailHighlighted) = self.highlightSearchTerms(text: address)
                isDetailHighlighted = detailHighlighted
                result.detail = detail
              }

              let (title, isTitleHighlighted) = self.highlightSearchTerms(text: venueName)

              if !isTitleHighlighted && !isDetailHighlighted {
                continue
              }

              result.title = title
              result.iconName = "Entry-Venue"
              result.cellType = .venue
              result.venue = venue

              results.append(result)
            } else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("Error occured when converting foodie types")
              }
            }
          }
          resultTableVC.push(results: results)
        }
      }
    }
  }
}

extension UniversalSearchViewController: MKLocalSearchCompleterDelegate {

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    var results:[SearchResult] = []
    var i = 0

    guard let resultTableVC = resultTableVC else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Search Result Table View Controller is nil!!")
      }
      return
    }

    for result in completer.results {

      let decimals = CharacterSet.decimalDigits
      let titleHasNumber = result.title.rangeOfCharacter(from: decimals) != nil
      let subtitleHasNumber = result.subtitle.rangeOfCharacter(from: decimals) != nil

      if !titleHasNumber && !subtitleHasNumber {
        let titleStr = result.title

        let (title, isTitleHighlighted) = self.highlightSearchTerms(text: titleStr)
        let (detail, isDetailHighlighted) = self.highlightSearchTerms(text: result.subtitle)
        if !isTitleHighlighted && !isDetailHighlighted {
          continue
        }

        var searchResult = SearchResult()
        searchResult.cellType = .location
        searchResult.title = title
        searchResult.detail = detail
        searchResult.iconName = "Entry-Venue"
        results.append(searchResult)
      }
      i = i + 1
      // limit 3 results from locations
      if( i > 3) {
        break
      }
    }
    resultTableVC.push(results: results)
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    // handle error
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

extension NSMutableAttributedString {
  @discardableResult func bold(_ text: String) -> NSMutableAttributedString {
    let attrs: [NSAttributedStringKey: Any] = [.font: UIFont(name: FoodieFont.Raleway.Bold, size: 17)!]
    let boldString = NSMutableAttributedString(string:text, attributes: attrs)
    append(boldString)

    return self
  }

  @discardableResult func normal(_ text: String) -> NSMutableAttributedString {
    let normal = NSAttributedString(string: text)
    append(normal)

    return self
  }
}

extension String {
  func index(of string: String, options: CompareOptions = .caseInsensitive) -> Index? {
    return range(of: string, options: options)?.lowerBound
  }
}
