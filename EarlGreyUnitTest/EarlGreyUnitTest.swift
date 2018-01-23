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
        GREYConfiguration.sharedInstance().setValue("/Users/specc/Desktop/results/", forConfigKey: kGREYConfigKeyArtifactsDirLocation)
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

    // add mark up from scratch by drawing a T
    private func addMarkup() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView_drawButton")).perform(grey_tap())

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.left))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.right))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.down))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView_backButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView_nextButton")).perform(grey_tap())
    }

    // edit the existing mark up by adding an extra line from middle to top
    private func modifyMarkup() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView_drawButton")).assert(grey_sufficientlyVisible()).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView")).perform(GREYActions.actionForMultiFingerSwipeSlow(in: GREYDirection.up
      , numberOfFingers: 4))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView_backButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("markupView_nextButton")).perform(grey_tap())
    }

    // use the camera to take a picture and add markup
    private func captureMoment() {
      let waitForCameraButton = GREYCondition.init(name: "wait for camera button") { () -> Bool in
        var error: NSError?
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("cameraView_captureButton")).assert(grey_enabled(), error: &error)
        return error == nil
      }

      let isCameraEnabled = waitForCameraButton?.wait(withTimeout: 15)
      if(isCameraEnabled)! {
        //EarlGrey.select(elementWithMatcher: grey_accessibilityID("cameraView_captureButton")).perform(GREYActions.actionForLongPress(withDuration: 15))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("cameraView_captureButton")).perform(grey_tap())

        waitForVisible("markupView")?.wait(withTimeout: 30)
        addMarkup()
      }
    }

    //press the ok button in the confirm dialog
    private func closeConfirmOkDialog() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("dialogButton_OK")).perform(grey_tap())
    }

    //close the Confirm dialog
    private func closeConfirmDialog() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("dialogButton_Confirm")).perform(grey_tap())
    }

    private func matchVisibleElement() -> MatchesBlock {
      let matches: MatchesBlock = { (element: Any?) -> Bool in
        if let element = element as? UIView {
          return !(element.isHidden)
        }
        else {
          return false
        }
      }
      return matches
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

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginSignUp_usernameField")).perform(GREYActions.action(forTypeText: "victor2\n0987654321t\n"))

      /*EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginSignUp_passwordField")).perform(GREYActions.action(forTypeText: ""))*/
      //EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginSignUp_loginButton")).perform(GREYActions.actionForTap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("loginSignUp_letsGoButton")).perform(GREYActions.actionForTap())
    }

    private func logout() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_profileButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("profileView_settingsButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("profileView_logoutButton")).perform(grey_tap())
      closeConfirmDialog()
    }

    // helper function to wait for element
    private func waitForVisible(_ accessibilityId: String) -> GREYCondition? {
      let waitForElement = GREYCondition.init(name: "wait for element"){() -> Bool in
        var error: NSError?
        EarlGrey.select(elementWithMatcher: grey_accessibilityID(accessibilityId)).assert(grey_notNil(), error: &error)
        return error == nil
      }
      return waitForElement
    }

    func testComposeEditDeleteStory1() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_cameraButton")).perform(grey_tap())

      captureMoment()

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView_titleTextField")).perform(GREYActions.action(forTypeText: "Test Journal\n"))

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView_venueButton")).perform(grey_tap())


      EarlGrey.select(elementWithMatcher: grey_accessibilityID("venueTableView")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("venueTableView_venueSearchBar")).perform(GREYActions.action(forTypeText: "KFC\n"))


      EarlGrey.select(elementWithMatcher: grey_text("KFC")).inRoot(grey_kindOfClass(UITableViewCell.self)).atIndex(0).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("momentCollectionView_addMomentButton")).perform(grey_tap())

      captureMoment()

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("momentCollectionView_addMomentButton")).perform(grey_tap())

      captureMoment()
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.up))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView_savePostButton")).perform(grey_tap())

      closeConfirmOkDialog()
    }

    func testComposeEditDeleteStory2() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView"))
        .assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_profileButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("coverEditButton_0")).perform(grey_tap())

      let nonHidden = GREYElementMatcherBlock.init(matchesBlock: matchVisibleElement()) { (description: Any) in
        let greyDescription:GREYDescription = description as! GREYDescription
        greyDescription.appendText("Select non hidden element")
      }

      EarlGrey.select(elementWithMatcher: nonHidden!).inRoot(grey_kindOfClass(MomentCollectionViewCell.self)).atIndex(1).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: nonHidden!).inRoot(grey_kindOfClass(MomentCollectionViewCell.self)).atIndex(1).perform(grey_doubleTap())
      modifyMarkup()
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView_titleTextField")).perform(GREYActions.action(forTypeText: " Edited \n"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.up))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView_savePostButton")).perform(grey_tap())
      closeConfirmOkDialog()
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.right))
    }

    func testComposeEditDeleteStory3() {
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView"))
        .assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_profileButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("coverEditButton_0")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("storyEntryView")).perform(GREYActions.actionForSwipeSlow(in: GREYDirection.up))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("deletePostButton")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityLabel("dialogButton_Delete")).perform(grey_tap())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).perform(GREYActions.actionForSwipeFast(in: GREYDirection.right))
    }

    func testMoveToBurquitlam() {
      // search richmond
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView"))
        .assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_locationField")).assert(grey_sufficientlyVisible()).perform(GREYActions.action(forTypeText: "Bridgeport\n"))
     // EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_locationField")).assert(grey_text("Bridgeport"))
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("searchButton")).assert(grey_sufficientlyVisible()).perform(GREYActions.actionForTap())

      // search buquitlam
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("feedCollectionNode")).assert(grey_sufficientlyVisible())
      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_locationField"))
        .assert(grey_interactable())
        .perform(clearTextField())

      EarlGrey.select(elementWithMatcher: grey_accessibilityID("discoverView_locationField"))
        .assert(grey_interactable())
        .perform(GREYActions.action(forTypeText: "Burquitlam\n"))

      waitForVisible("discoverView")?.wait(withTimeout: 20)

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

    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    */
    
}
