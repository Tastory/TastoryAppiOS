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

  enum ResultsCategory: Int {
    case Top = 0
    case Venues = 1
    case People = 2
    case Stories = 3
    // make sure you update the count value if you add a new category
    static var count: Int { return ResultsCategory.Stories.hashValue + 1}
  }

  enum Direction {
    case Left
    case Right
  }

  // MARK: - Private Instance Functions
  private var searchKeyWord = ""
  private var resultPageVC: ResultPageViewController?
  private var toPageIdx = 0
  private let underlineBorder = CALayer()
  private var lastPointX:CGFloat = 0

  // MARK: - Public Instance Functions
  var delegate: SearchResultDisplayDelegate?
  var currentLocation: CLLocation?

  // MARK: - IBOutlets
  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var tablePlaceHolder: UIView!
  @IBOutlet weak var categoryButton: SegmentedControl!

  // MARK: - IBActions
  @IBAction func categoryClicked(_ sender: UISegmentedControl) {
    underlineBorder.borderWidth = 0
    let currentIdx = sender.selectedSegmentIndex
    //categoryButton.layer.addSublayer(underlineBorder)

    guard let category = ResultsCategory.init(rawValue: currentIdx) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Failed to initialize ResultsCategory enum")
      }
      return
    }

    guard let resultTableVC = resultPageVC else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Search Result Table View Controller is nil!!")
      }
      return
    }

    var direction: UIPageViewControllerNavigationDirection = .forward
      if(categoryButton.previousSelectedSegmentIndex > currentIdx) {
      direction = .reverse
    }

    resultTableVC.display(category: category, direction: direction) { (isCompleted) in
      self.underlineBorder.borderWidth = 2
      self.underlineCategory()
      CCLog.verbose("animate from \(self.categoryButton.previousSelectedSegmentIndex) to \(self.categoryButton.selectedSegmentIndex)")
    }
  }

  @IBAction func cancelAction(_ sender: UIButton) {
    self.navigationController?.popViewController(animated: true)
    //popDismiss(animated: true)
  }

  // MARK: - Private Instance Functions

  private func underlineCategory(xOffset: CGFloat = 0) {

      underlineBorder.removeFromSuperlayer()
      let width: CGFloat = categoryButton.frame.size.width/4
      let x = (CGFloat(categoryButton.selectedSegmentIndex) * width) + (xOffset * width)
      let y = categoryButton.frame.size.height - underlineBorder.borderWidth
      underlineBorder.frame = CGRect(x: x, y: y, width: width, height: underlineBorder.borderWidth)
    DispatchQueue.main.async{
      self.categoryButton.layer.addSublayer(self.underlineBorder)
    }
  }

  private func highlightSearchTerms(text: String, isDetail: Bool = false) -> (NSMutableAttributedString, Bool) {
    let index = text.index(of: searchKeyWord)
    let attrText = NSMutableAttributedString()

    if let index = index {
      attrText.normal(String(text[text.startIndex..<index]))
      let offsetIdx = text.index(index, offsetBy: searchKeyWord.count)
      if isDetail {
         attrText.bold12(String(text[index..<offsetIdx]))
      } else {
         attrText.bold14(String(text[index..<offsetIdx]))
      }

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
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "ResultPageViewController") as? ResultPageViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of ResultPageViewController Class!!")
      }
      return
    }
    resultPageVC = viewController
    viewController.displayDelegate = delegate
    viewController.delegate = self

    self.addChildViewController(viewController)
    tablePlaceHolder.addSubview(viewController.view)


    categoryButton.tintColor = UIColor.clear
    categoryButton.removeAllSegments()
    categoryButton.insertSegment(withTitle: "Top", at: ResultsCategory.Top.rawValue, animated: false)
    categoryButton.insertSegment(withTitle: "Venues", at: ResultsCategory.Venues.rawValue, animated: false)
    categoryButton.insertSegment(withTitle: "People", at: ResultsCategory.People.rawValue, animated: false)
    categoryButton.insertSegment(withTitle: "Stories", at: ResultsCategory.Stories.rawValue, animated: false)
    categoryButton.selectedSegmentIndex = ResultsCategory.Top.rawValue

    // initializes underline
    underlineBorder.borderColor = UIColor.black.cgColor
    underlineBorder.borderWidth = 2
    underlineCategory()


    // find scroll view within uipagecontroller
    for view in viewController.view.subviews {
      if view is UIScrollView, let view = view as? UIScrollView {
        view.delegate = self
      }
    }

    // setup fonts
     UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedStringKey.font.rawValue : UIFont(name: "Raleway-Regular", size: 12)!, NSAttributedStringKey.strokeColor.rawValue : FoodieGlobal.Constants.TextColor]
    categoryButton.setTitleTextAttributes([NSAttributedStringKey.font.rawValue : UIFont(name: "Raleway-Medium", size: 14)!, NSAttributedStringKey.strokeColor.rawValue : FoodieGlobal.Constants.TextColor,NSAttributedStringKey.foregroundColor: FoodieGlobal.Constants.TextColor], for: UIControlState.selected)
    categoryButton.setTitleTextAttributes([NSAttributedStringKey.font.rawValue : UIFont(name: "Raleway-Regular", size: 14)!, NSAttributedStringKey.strokeColor.rawValue : FoodieGlobal.Constants.TextColorHalfAlpha, NSAttributedStringKey.foregroundColor: FoodieGlobal.Constants.TextColorHalfAlpha], for: UIControlState.normal)

  }

  @objc func search() {

    guard let resultTableVC = resultPageVC else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Search Result Table View Controller is nil!!")
      }
      return
    }

    resultTableVC.clearAllResults()

    guard let topVC = resultTableVC.pages[ResultsCategory.Top.rawValue] as? SearchResultTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Failed to unwrap SearchResultTableViewController from ResultPageViewController")
      }
      return
    }

    guard let venueVC = resultTableVC.pages[ResultsCategory.Venues.rawValue] as? SearchResultTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Failed to unwrap SearchResultTableViewController from ResultPageViewController")
      }
      return
    }

    guard let peopleVC = resultTableVC.pages[ResultsCategory.People.rawValue] as? SearchResultTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Failed to unwrap SearchResultTableViewController from ResultPageViewController")
      }
      return
    }

    guard let storiesVC = resultTableVC.pages[ResultsCategory.Stories.rawValue] as? SearchResultTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Failed to unwrap SearchResultTableViewController from ResultPageViewController")
      }
      return
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

          if( i >= 2) {
            break
          }

          var result = SearchResult()

          let (title, highlighted) = highlightSearchTerms(text: meal.rawValue)

          if !highlighted {
            continue
          }

          result.title = title
          result.cellType = .meal
          result.meal = meal
          result.iconName = "Search-MealTypeIcon"
          results.append(result)

          i = i + 1

        }
        topVC.pushFront(results: results)
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

          if( i >= 2) {
            break
          }

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
          result.iconName = "Search-CategoryIcon"
          results.append(result)

          i = i + 1

        }
        topVC.pushFront(results: results)
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

          if( i >= 2) {
            break
          }

          guard let venueName = venue.name else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
              CCLog.fatal("venueName is nil")
            }
            return
          }

          var result = SearchResult()
          var isDetailHighlighted = false
          if let address = venue.streetAddress {
            let (detail, highlightedDetail) = self.highlightSearchTerms(text: address, isDetail: true)
            isDetailHighlighted = highlightedDetail
            result.detail = detail
          }

          let (title, highlighted) = self.highlightSearchTerms(text: venueName)
          if !highlighted && !isDetailHighlighted {
            continue
          }

          result.title = title
          result.iconName = "Search-VenueIcon"
          result.cellType = .venue
          result.venue = venue
          results.append(result)
          i = i + 1

        }
        topVC.push(results: results)
        venueVC.push(results: results)
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
          var venues: [SearchResult] = []
          var users: [SearchResult] = []
          var stories: [SearchResult] = []

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
              let (detail, isDetailHighlighted) = self.highlightSearchTerms(text: venueName + " @" + userName, isDetail: true)
              if isTitleHighlighted || isDetailHighlighted {
                result.title = title
                result.detail = detail
                result.iconName = "Search-StoryIcon"
                result.story = story

                results.append(result)
                stories.append(result)
              }

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
              let (detail, isDetailHighlighted) = self.highlightSearchTerms(text: "@" + userName, isDetail:  true)
              if !isTitleHighlighted && !isDetailHighlighted {
                continue
              }

              result.title = title
              result.detail = detail
              result.iconName = "Search-UserIcon"
              result.cellType = .user
              result.user = user

              results.append(result)
              users.append(result)
            } else if obj is FoodieVenue, let venue = obj as? FoodieVenue {

              guard let venueName = venue.name else {
                AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
                  CCLog.fatal("venueName is nil")
                }
                return
              }

              var isDetailHighlighted = false
              if let address = venue.streetAddress {
                let (detail, detailHighlighted) = self.highlightSearchTerms(text: address, isDetail: true)
                isDetailHighlighted = detailHighlighted
                result.detail = detail
              }

              let (title, isTitleHighlighted) = self.highlightSearchTerms(text: venueName)

              if !isTitleHighlighted && !isDetailHighlighted {
                continue
              }

              result.title = title
              result.iconName = "Search-VenueIcon"
              result.cellType = .venue
              result.venue = venue

              venues.append(result)
              results.append(result)
            } else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("Error occured when converting foodie types")
              }
            }
          }
          topVC.push(results: results)
          venueVC.push(results: venues)
          peopleVC.push(results: users)
          storiesVC.push(results: stories)
        }
      }
    }
  }
}

extension UniversalSearchViewController: MKLocalSearchCompleterDelegate {

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    var results:[SearchResult] = []
    var i = 0

    guard let resultTableVC = resultPageVC else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Search Result Table View Controller is nil!!")
      }
      return
    }

    guard let topVC = resultTableVC.pages[ResultsCategory.Top.rawValue] as? SearchResultTableViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Failed to unwrap SearchResultTableViewController from ResultPageViewController")
      }
      return
    }

    for result in completer.results {

      if( i >= 2) {
        break
      }

      let decimals = CharacterSet.decimalDigits
      let titleHasNumber = result.title.rangeOfCharacter(from: decimals) != nil
      let subtitleHasNumber = result.subtitle.rangeOfCharacter(from: decimals) != nil

      if !titleHasNumber && !subtitleHasNumber {
        let titleStr = result.title

        let (title, isTitleHighlighted) = self.highlightSearchTerms(text: titleStr)
        let (detail, isDetailHighlighted) = self.highlightSearchTerms(text: result.subtitle, isDetail: true)
        if !isTitleHighlighted && !isDetailHighlighted {
          continue
        }

        var searchResult = SearchResult()
        searchResult.cellType = .location
        searchResult.title = title
        searchResult.detail = detail
        searchResult.iconName = "Search-LocationIcon"
        results.append(searchResult)
      }
      i = i + 1
    }
    topVC.push(results: results)
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
      CCLog.fatal("An error occured while searching for location error: \(error.localizedDescription)")
    }
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

extension UniversalSearchViewController: UIPageViewControllerDelegate {
  func pageViewController(_: UIPageViewController, willTransitionTo: [UIViewController]) {
    guard let resultTableVC = resultPageVC else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Search Result Table View Controller is nil!!")
      }
      return
    }

    if willTransitionTo.isEmpty {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("Impossible the transiton cant have empty array")
      }
      return
    }

    toPageIdx = resultTableVC.pages.index(of: willTransitionTo[0])!
  }

  func pageViewController(_: UIPageViewController, didFinishAnimating: Bool, previousViewControllers: [UIViewController], transitionCompleted: Bool) {
    if transitionCompleted {
      categoryButton.selectedSegmentIndex = toPageIdx
    }
  }
}

extension UniversalSearchViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {

      let point:CGPoint = scrollView.contentOffset
      let percentComplete: CGFloat

      percentComplete = ((point.x) - self.view.frame.size.width)/CGFloat(self.view.frame.size.width);
      underlineCategory(xOffset: percentComplete)
   }
}


