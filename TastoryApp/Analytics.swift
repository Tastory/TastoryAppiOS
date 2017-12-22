//
//  Analytics.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-15.
//  Copyright © 2017 Tastory. All rights reserved.
//


import Fabric
import Crashlytics


class Analytics {
  
  // MARK: - Signup & Login Events
  
  enum LoginSignupMethod: String {
    case email
    case facebook
    case guest
  }
  
  
  static func logSignupEvent(method: LoginSignupMethod, success: Bool, note: String) {  // FB vs E-mail, should total to AppOpen?
    if method == .guest {
      CCLog.assert("Shouldn't be logging Guest mode as Signup")
    }
    Answers.logSignUp(withMethod: method.rawValue, success: success as NSNumber, customAttributes: ["Note" : note])
  }
  
  
  static func logLoginEvent(method: LoginSignupMethod, success: Bool, note: String) {  // FB vs E-mail, should total to AppOpen?
    Answers.logLogin(withMethod: method.rawValue, success: success as NSNumber, customAttributes: ["Note" : note])
  }
  

  // MARK: - Search & Jump Events
  
  static func loginDiscoverFilterSearch(categoryIDs: [String], priceUpperLimit: Double, priceLowerLimit: Double, success: Bool, note: String, stories: Int) {  // Which filters are on?
    Answers.logCustomEvent(withName: "Filter", customAttributes: ["Category IDs" : categoryIDs,
                                                                  "Number of Categories" : categoryIDs.count,
                                                                  "Price Upper Limit" : priceUpperLimit,
                                                                  "Price Lower Limit" : priceLowerLimit,
                                                                  "Success" : success,
                                                                  "Note" : note,
                                                                  "Stories" : stories])
  }
  
  
  static func loginDiscoverSearchBar(typedTerm: String, success: Bool, searchedTerm: String, note: String) {
    Answers.logSearch(withQuery: typedTerm, customAttributes: ["Success" : success,
                                                               "Searched" : searchedTerm,
                                                               "Note" : note])
  }
  
  
  // MARK: - Content View Events

  enum StoryLaunchType: String {
    case carousel
    case mosaic
    case profile
  }
  
  
  static func logStoryViewEvent(storyId: String, name: String, authorId: String, launchType: StoryLaunchType, totalMoments: Int) {
    Answers.logContentView(withName: name, contentType: "Story", contentId: storyId, customAttributes: ["Author ID" : authorId,
                                                                                                        "Launch Type" : launchType,
                                                                                                        "Total Moments" : totalMoments])
  }
  
  
  static func logStoryOwnViewEvent(launchType: StoryLaunchType) {
    Answers.logCustomEvent(withName: "Story Own", customAttributes: ["Launch Type" : launchType])
  }
  
  
  static func logStoryExitEvent(storyId: String,
                                name: String,
                                storyPercentage: Double,
                                authorId: String,
                                momentId: String,
                                momentNumber: Int,
                                totalMoments: Int,
                                videoPercentage: Double) {
    
    Answers.logCustomEvent(withName: "Story Exit", customAttributes: ["Story ID" : storyId,
                                                                      "Story Name" : name,
                                                                      "Story Percentage" : storyPercentage,
                                                                      "Author ID" : authorId,
                                                                      "Moment ID" : momentId,
                                                                      "Moment Number" : momentNumber,
                                                                      "Total Moments" : totalMoments,
                                                                      "Video %" : videoPercentage])
  }
  
  
  static func logMomentSwipeEvent(url: String,
                                  message: String,
                                  storyPercentage: Double,
                                  momentId: String,
                                  momentNumber: Int,
                                  totalMoments: Int,
                                  mediaType: FoodieMediaType,
                                  storyId: String,
                                  storyName: String,
                                  authorId: String) {
    
    Answers.logCustomEvent(withName: "Moment Swiped", customAttributes: ["URL" : url,
                                                                        "Message" : message,
                                                                        "Story Percentage" : storyPercentage,
                                                                        "Moment ID" : momentId,
                                                                        "Moment Number" : momentNumber,
                                                                        "Total Moments" : totalMoments,
                                                                        "Media Type" : mediaType.rawValue,
                                                                        "Story ID" : storyId,
                                                                        "Story Name" : storyName,
                                                                        "Author ID" : authorId])
  }
  
  
  static func logMomentVenueEvent(venueId: String,
                                  venueName: String,
                                  storyPercentage: Double,
                                  momentId: String,
                                  momentNumber: Int,
                                  totalMoments: Int,
                                  mediaType: FoodieMediaType,
                                  storyId: String,
                                  storyName: String,
                                  authorId: String) {
    
    Answers.logCustomEvent(withName: "Venue Clicked", customAttributes: ["Venue ID" : venueId,
                                                                         "Venue Name" : venueName,
                                                                         "Story Percentage" : storyPercentage,
                                                                         "Moment ID" : momentId,
                                                                         "Moment Number" : momentNumber,
                                                                         "Total Moments" : totalMoments,
                                                                         "Media Type" : mediaType.rawValue,
                                                                         "Story ID" : storyId,
                                                                         "Story Name" : storyName,
                                                                         "Author ID" : authorId])
    
  }
  
  
  static func logMomentProfileEvent(authorId: String,
                                    storyPercentage: Double,
                                    momentId: String,
                                    momentNumber: Int,
                                    totalMoments: Int,
                                    mediaType: FoodieMediaType,
                                    storyId: String,
                                    storyName: String) {
    
    Answers.logCustomEvent(withName: "Profile Clicked", customAttributes: ["Author ID" : authorId,
                                                                           "Story Percentage" : storyPercentage,
                                                                           "Moment ID" : momentId,
                                                                           "Moment Number" : momentNumber,
                                                                           "Total Moments" : totalMoments,
                                                                           "Media Type" : mediaType.rawValue,
                                                                           "Story ID" : storyId,
                                                                           "Story Name" : storyName])
    
  }
  
  
  
  // MARK: - Composition Events
  
  static func logCameraPhotoEvent() {
    Answers.logCustomEvent(withName: "Photo Captured", customAttributes: nil)
  }
  
  static func logCameraVideoEvent(duration: Double) {
    Answers.logCustomEvent(withName: "Video Captured", customAttributes: ["Duration" : duration])
  }

  static func logPickerPhotoEvent(width: Double, aspectRatio: Double) {
    Answers.logCustomEvent(withName: "Photo Picked", customAttributes: ["Width" : width,
                                                                        "Aspect Ratio" : "\(aspectRatio.truncate(places: 1))"])
  }
  
  static func logPickerVideoEvent(width: Double, aspectRatio: Double, duration: Double) {
    Answers.logCustomEvent(withName: "Video Picked", customAttributes: ["Width" : width,
                                                                        "Aspect Ratio" : "\(aspectRatio.truncate(places: 1))",
                                                                        "Duration" : duration])
  }
  
  static func logStoryPosted(authorId: String, storyId: String, totalMoments: Int) {
    Answers.logCustomEvent(withName: "Story Posted", customAttributes: ["Author ID" : authorId,
                                                                        "Story ID" : storyId,
                                                                        "Total Moments" : totalMoments])
  }
  
  static func logStoryEditAttempted(authorId: String, storyId: String) {
    Answers.logCustomEvent(withName: "Story Edit Attempted", customAttributes: ["Author ID" : authorId,
                                                                                "Story ID" : storyId])
  }
  
  static func logStoryEditSaved(authorId: String, storyId: String) {
    Answers.logCustomEvent(withName: "Story Edit Saved", customAttributes: ["Author ID" : authorId,
                                                                            "Story ID" : storyId])
  }
}
