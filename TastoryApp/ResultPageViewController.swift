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
  // MARK: - Public Instance Variables
  var displayDelegate: SearchResultDisplayDelegate?
  var pages: [UIViewController] = []

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

  override func viewDidLoad()
  {
    super.viewDidLoad()
    self.dataSource = self

    let storyboard = UIStoryboard(name: "Filters", bundle: nil)

    var i = 0
    while i < 4 {
      guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "SearchResultTableViewController") as? SearchResultTableViewController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("ViewController initiated not of SearchResultTableViewController Class!!")
        }
        return
      }
      viewController.delegate = displayDelegate
      // TODO fix this HACKY way to load up all view controllers..... 
      setViewControllers([viewController], direction: .forward, animated: true, completion: nil)
      pages.append(viewController)
      i = i + 1
    }

    if let firstVC = pages.first
    {
      setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
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

