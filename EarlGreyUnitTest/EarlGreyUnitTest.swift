//
//  EarlGreyUnitTest.swift
//  EarlGreyUnitTest
//
//  Created by Victor Tsang on 2018-01-14.
//  Copyright © 2018 Tastry. All rights reserved.
//

import XCTest
import EarlGrey


@testable import TastoryApp

class EarlGreyUnitTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        GREYConfiguration.sharedInstance().setValue(false, forConfigKey: kGREYConfigKeyAnalyticsEnabled)

    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLogin() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("usernameField")).perform(GREYActions.action(forTypeText: "victor2"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("passwordField")).perform(GREYActions.action(forTypeText: "0987654321t"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginButton")).perform(GREYActions.actionForTap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("letsGoButton")).perform(GREYActions.actionForTap())



    }

    func testMap() {

      /*let alert = FBAlert(application: XCUIApplication.init(privateWithPath: nil,
                                                            bundleID: "my.app.bundle"))
      alert.isPresent()
      */
      /*
      addUIInterruptionMonitor(withDescription: "Location Dialog") { (alert) -> Bool in
        let button = alert.buttons["Allow"]
        if button.exists {
          button.tap()
          return true
        }
        return false
      }
      XCUIApplication().swipeUp()
      */


      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverViewController")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNodeController")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("locationField")).perform(GREYActions.action(forTypeText: "Burquitlam\n"))



      var error: NSError?
      var isVisible = false
      while(!isVisible) {
        error = nil
        EarlGrey.select(elementWithMatcher:grey_accessibilityID("feedCollectionCellNode_2")).assert(grey_interactable(), error: &error)
        if(error != nil) {
          EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNodeController")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.left))
          isVisible = false
        } else {
          isVisible = true
        }
      }
      EarlGrey.select(elementWithMatcher:grey_accessibilityID("feedCollectionCellNode_2")).perform(grey_tap())

     //EarlGrey.select(elementWithMatcher: matcherForJunk).perform(grey_tap())




      //feedCollectionCellNode
      /*
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverViewController")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNodeController")).assert(grey_sufficientlyVisible())

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNodeController")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.right))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("searchButton")).perform(GREYActions.actionForTap())
     // EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverViewController")).perform(grey_scrollInDirection(GREYDirection.left, 100))
      */
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
