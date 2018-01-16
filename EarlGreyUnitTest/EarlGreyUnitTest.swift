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

    struct Constants {
      static let enableLoginAndLogout = false
    }

    override func setUp() {
        super.setUp()
        GREYConfiguration.sharedInstance().setValue(false, forConfigKey: kGREYConfigKeyAnalyticsEnabled)
        if(Constants.enableLoginAndLogout) {
          login()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        if(Constants.enableLoginAndLogout) {
          logout()
        }

        super.tearDown()
    }

    private func captureMoment() {
      let waitForCameraButton = GREYCondition.init(name: "wait for camera button") { () -> Bool in
        var error: NSError?
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("captureButton")).assert(grey_enabled(), error: &error)
        return error == nil
      }

      let isCameraEnabled = waitForCameraButton?.wait(withTimeout: 15)
      if(isCameraEnabled)! {
        //EarlGrey.select(elementWithMatcher: grey_accessibilityID("captureButton")).perform(GREYActions.actionForLongPress(withDuration: 15))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("captureButton")).perform(grey_tap())

        waitForVisible("markupView")?.wait(withTimeout: 15)

        EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).assert(grey_sufficientlyVisible())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("drawButton")).assert(grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForMultiFingerSwipeSlow(in: GREYDirection.up
          , numberOfFingers: 4))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.left))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.right))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.down))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("backButton")).perform(grey_tap())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("nextButton")).perform(grey_tap())


      }
    }

    private func confirmOkDialog() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("dialogButton_OK")).perform(grey_tap())
    }

    private func closeConfirmDialog() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("dialogButton_Confirm")).perform(grey_tap())
    }

    private func clearTextField() -> GREYAction {
      let clearTextFieldBlock = GREYActionBlock.action(withName: "clearTextField") { element, error in

        /*if error != nil {
          return false
        }*/

        let view = element as! UITextField
          view.text = ""
        return view.text == ""
      }
      return clearTextFieldBlock!
    }

    private func login() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("usernameField")).perform(GREYActions.action(forTypeText: "victor2"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("passwordField")).perform(GREYActions.action(forTypeText: "0987654321t"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginButton")).perform(GREYActions.actionForTap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("letsGoButton")).perform(GREYActions.actionForTap())
    }

    private func logout() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("profileButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("settingsButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("logoutButton")).perform(grey_tap())
      closeConfirmDialog()
    }

    private func waitForVisible(_ accessibilityId: String) -> GREYCondition? {
      let waitForElement = GREYCondition.init(name: "wait for element"){() -> Bool in
        var error: NSError?
        EarlGrey.select(elementWithMatcher: grey_accessibilityID(accessibilityId)).assert(grey_notNil(), error: &error)
        return error == nil
      }
      return waitForElement
    }



    func testComposeStory() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("cameraButton")).perform(grey_tap())

      captureMoment()

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("titleTextField")).perform(GREYActions.action(forTypeText: "Test Journal\n"))

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("venueButton")).perform(grey_tap())


      EarlGrey.select(elementWithMatcher: grey_accessibilityID("venueTableView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("venueSearchBar")).perform(GREYActions.action(forTypeText: "KFC\n"))

      EarlGrey.select(elementWithMatcher: grey_text("KFC")).inRoot(grey_kindOfClass(UITableViewCell.self)).atIndex(0).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("addMomentButton")).perform(grey_tap())

      captureMoment()

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("addMomentButton")).perform(grey_tap())

      captureMoment()
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.up))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("savePostButton")).perform(grey_tap())

      confirmOkDialog()
        /*
        let hidden = { () -> GREYAssertionBlock in
          return GREYAssertionBlock.assertion(withName: "Hidden element",
                                              assertionBlockWithError: {
                                                (element: Any?, errorOrNil: UnsafeMutablePointer<NSError?>?) -> Bool in
                                                guard let view = element! as! UITableView as UITableView! else {
                                                  let errorInfo = [NSLocalizedDescriptionKey:
                                                    NSLocalizedString("Element is not a UIView",
                                                                      comment: "")]
                                                  errorOrNil?.pointee =
                                                    NSError(domain: kGREYInteractionErrorDomain,
                                                            code: 2,
                                                            userInfo: errorInfo)
                                                  return false
                                                }
                                                return view.isHidden
          })
        }
        */


        //EarlGrey.select(elementWithMatcher: grey_kindOfClass(UITableViewCell.self)).assert(grey_text("KFC")).perform(grey_tap())
        //EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("venueTableBackButton")).perform(grey_tap())



        //EarlGrey.select(elementWithMatcher: grey_accessibilityID("venueButton"))

      //EarlGrey.select(elementWithMatcher: grey_accessibilityID("captureButton")).perform(GREYActions.actionForLongPress(withDuration: CFTimeInterval(15)))

    }

    func testDeleteStory() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("profileButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("coverEditButton_0")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.up))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("deletePostButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("dialogButton_Delete")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.right))
    }

    func testMoveToBurquitlam() {

      // search richmond
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("locationField")).perform(GREYActions.action(forTypeText: "Bridgeport\n"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("searchButton")).assert(grey_interactable()).perform(GREYActions.actionForTap())

      // search buquitlam
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("locationField"))
        .assert(grey_interactable())
        .perform(clearTextField())

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("locationField"))
        .assert(grey_interactable())
        .perform(GREYActions.action(forTypeText: "Burquitlam\n"))

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView"))
        .assert(grey_sufficientlyVisible())
        .perform(GREYActions.actionForPinchFast(in: GREYPinchDirection.inward, withAngle: 0))

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView"))
        .assert(grey_sufficientlyVisible())
        .perform(GREYActions.actionForSwipeSlow(in: GREYDirection.up, xOriginStartPercentage: 0.5, yOriginStartPercentage: 0.1))

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("searchButton")).perform(GREYActions.actionForTap())

      // search for collectionNode with title "2"
      var error: NSError?
      var isVisible = false
      while(!isVisible) {
        error = nil
        EarlGrey.select(elementWithMatcher:grey_accessibilityID("feedCollectionCellNode_2")).assert(grey_interactable(), error: &error)
        if(error != nil) {
          EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.left))
          isVisible = false
        } else {
          isVisible = true
        }
      }
      EarlGrey.select(elementWithMatcher:grey_accessibilityID("feedCollectionCellNode_2")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyView"))
        .perform(GREYActions.actionForSwipeFast(in: GREYDirection.down))
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
