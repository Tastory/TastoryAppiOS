//
//  Analytics.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-15.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
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
  
  static func loginDiscoverFilterSearch(userID: String, categoryIDs: [String], priceUpperLimit: Double, priceLowerLimit: Double, success: Bool, note: String, stories: Int) {  // Which filters are on?
    Answers.logCustomEvent(withName: "Filter", customAttributes: ["User ID" : userID,
                                                                  "Category IDs" : categoryIDs,
                                                                  "Number of Categories" : categoryIDs.count,
                                                                  "Price Upper Limit" : priceUpperLimit,
                                                                  "Price Lower Limit" : priceLowerLimit,
                                                                  "Success" : success,
                                                                  "Note" : note,
                                                                  "Stories" : stories])
  }
  
  
  static func loginDiscoverSearchBar(userID: String, typedTerm: String, success: Bool, searchedTerm: String, note: String) {
    Answers.logSearch(withQuery: typedTerm, customAttributes: ["User ID" : userID,
                                                               "Success" : success,
                                                               "Searched" : searchedTerm,
                                                               "Note" : note])
  }
  
  
  // MARK: - Content View Events

  enum StoryLaunchType: String {
    case carousel
    case mosaic
    case profile
  }
  
  
  static func logStoryViewEvent(userID: String, storyId: String, name: String, authorId: String, launchType: StoryLaunchType, totalMoments: Int) {
    Answers.logContentView(withName: name, contentType: "Story", contentId: storyId, customAttributes: ["User ID" : userID,
                                                                                                        "Author ID" : authorId,
                                                                                                        "Launch Type" : launchType.rawValue,
                                                                                                        "Total Moments" : totalMoments])
  }
  
  
  static func logStoryOwnViewEvent(userID: String, launchType: StoryLaunchType) {
    Answers.logCustomEvent(withName: "Story Own", customAttributes: ["User ID" : userID,
                                                                     "Launch Type" : launchType])
  }
  
  
  static func logStoryExitEvent(userID: String,
                                storyId: String,
                                name: String,
                                storyPercentage: Double,
                                authorId: String,
                                momentId: String,
                                momentNumber: Int,
                                totalMoments: Int,
                                videoPercentage: Double) {
    
    Answers.logCustomEvent(withName: "Story Exit", customAttributes: ["User ID" : userID,
                                                                      "Story ID" : storyId,
                                                                      "Story Name" : name,
                                                                      "Story Percentage" : storyPercentage,
                                                                      "Author ID" : authorId,
                                                                      "Moment ID" : momentId,
                                                                      "Moment Number" : momentNumber,
                                                                      "Total Moments" : totalMoments,
                                                                      "Video %" : videoPercentage])
  }
  
  
  static func logMomentSwipeEvent(userID: String,
                                  url: String,
                                  message: String,
                                  storyPercentage: Double,
                                  momentId: String,
                                  momentNumber: Int,
                                  totalMoments: Int,
                                  mediaType: FoodieMediaType,
                                  storyId: String,
                                  storyName: String,
                                  authorId: String) {
    
    Answers.logCustomEvent(withName: "Moment Swiped", customAttributes: ["User ID" : userID,
                                                                         "URL" : url,
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
  
  
  static func logMomentVenueEvent(userID: String,
                                  venueId: String,
                                  venueName: String,
                                  storyPercentage: Double,
                                  momentId: String,
                                  momentNumber: Int,
                                  totalMoments: Int,
                                  mediaType: FoodieMediaType,
                                  storyId: String,
                                  storyName: String,
                                  authorId: String) {
    
    Answers.logCustomEvent(withName: "Venue Clicked", customAttributes: ["User ID" : userID,
                                                                         "Venue ID" : venueId,
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
  
  
  static func logMomentProfileEvent(userID: String,
                                    authorId: String,
                                    storyPercentage: Double,
                                    momentId: String,
                                    momentNumber: Int,
                                    totalMoments: Int,
                                    mediaType: FoodieMediaType,
                                    storyId: String,
                                    storyName: String) {
    
    Answers.logCustomEvent(withName: "Profile Clicked", customAttributes: ["User ID" : userID,
                                                                           "Author ID" : authorId,
                                                                           "Story Percentage" : storyPercentage,
                                                                           "Moment ID" : momentId,
                                                                           "Moment Number" : momentNumber,
                                                                           "Total Moments" : totalMoments,
                                                                           "Media Type" : mediaType.rawValue,
                                                                           "Story ID" : storyId,
                                                                           "Story Name" : storyName])
    
  }
  
  
  
  // MARK: - Composition Events
  
  static func logCameraPhotoEvent(userID: String) {
    Answers.logCustomEvent(withName: "Photo Captured", customAttributes: ["User ID" : userID])
  }
  
  static func logCameraVideoEvent(userID: String, duration: Double) {
    Answers.logCustomEvent(withName: "Video Captured", customAttributes: ["User ID" : userID, "Duration" : duration])
  }

  static func logPickerPhotoEvent(userID: String, width: Double, aspectRatio: Double) {
    Answers.logCustomEvent(withName: "Photo Picked", customAttributes: ["User ID" : userID, "Width" : width,
                                                                        "Aspect Ratio" : "\(aspectRatio.truncate(places: 1))"])
  }
  
  static func logPickerVideoEvent(userID: String, width: Double, aspectRatio: Double, duration: Double) {
    Answers.logCustomEvent(withName: "Video Picked", customAttributes: ["User ID" : userID, "Width" : width,
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
  
  
  
  // MARK: - Foursquare Request Tracking
  
  enum FoursquareRequestType: String {
    case venueCompact
    case venueDetails
    case venueHours
    case categoryList
  }
  
  
  static func logFoursquareRequest(type: FoursquareRequestType ) {
    Answers.logCustomEvent(withName: "Foursquare Request", customAttributes:["Type" : type.rawValue])
  }
}
