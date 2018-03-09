//
//  ResultPageViewController.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-02-28.
//  Copyright © 2018 Tastry. All rights reserved.
//


import UIKit

class ResultPageViewController: UIPageViewController
{

  // MARK: - Private Instance Variables
  private var toIdx = 0

  // MARK: - Public Instance Variables
  public var displayDelegate: SearchResultDisplayDelegate?
  public var keywordDelegate: SearchKeywordDelegate?
  public var pages: [UIViewController] = []

  // MARK: - Public Instance Functions
  public func clearAllResults()   {
    for page in pages {
      guard let viewController = page as? SearchResultTableViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Failed to unwrap SearchResultTableViewController")
        }
        return
      }
      viewController.clearTable()
    }
  }

  public func display(category: UniversalSearchViewController.ResultsCategory, direction: UIPageViewControllerNavigationDirection, completion: @escaping ((Bool) -> Swift.Void)) {
      setViewControllers([pages[category.rawValue]], direction: direction, animated: true, completion: completion)
  }

  override func viewDidLoad()
  {
    super.viewDidLoad()
    self.dataSource = self
   
    let storyboard = UIStoryboard(name: "Filters", bundle: nil)

    var i = UniversalSearchViewController.ResultsCategory.count
    // the tablesVC are added in reverse to prevent scroll loop after you display the first result in Top
    while i > 0 {
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SearchResultTableViewController") as? SearchResultTableViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("ViewController initiated not of SearchResultTableViewController Class!!")
        }
        return
      }
      viewController.displayDelegate = displayDelegate
      viewController.keywordDelegate = keywordDelegate
      // TODO fix this HACKY way to load up all view controllers.....
      setViewControllers([viewController], direction: .reverse, animated: true, completion: nil)
      pages.insert(viewController, at: 0)
      i = i - 1
    }
  }
}

extension ResultPageViewController: UIPageViewControllerDataSource
{
  func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

    guard let currentIdx = pages.index(of: viewController) else { return nil }
    let previousIndex = currentIdx - 1

    if previousIndex < 0 {
      return nil
    } else {
       return pages[previousIndex]
    }
  }

  func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
  {
    guard let currentIdx = pages.index(of: viewController) else { return nil }
    let nextIndex = currentIdx + 1

    if nextIndex >= pages.count {
      return nil
    } else {
      return pages[nextIndex]
    }
  }
}



