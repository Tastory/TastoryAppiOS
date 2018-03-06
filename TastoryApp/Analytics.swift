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
  
  static func loginDiscoverFilterSearch(username: String, categoryIDs: [String], priceUpperLimit: Double, priceLowerLimit: Double, mealTypes: [String], success: Bool, note: String, stories: Int) {  // Which filters are on?
    Answers.logCustomEvent(withName: "Filter", customAttributes: ["Username" : username,
                                                                  "Category IDs" : categoryIDs,
                                                                  "Number of Categories" : categoryIDs.count,
                                                                  "Price Upper Limit" : priceUpperLimit,
                                                                  "Price Lower Limit" : priceLowerLimit,
                                                                  "Meal Types:": mealTypes,
                                                                  "Number of Meal Types" : mealTypes.count,
                                                                  "Success" : success,
                                                                  "Note" : note,
                                                                  "Stories" : stories])
  }
  
  
  static func loginDiscoverSearchBar(username: String, typedTerm: String, success: Bool, searchedTerm: String, note: String) {
    Answers.logSearch(withQuery: typedTerm, customAttributes: ["Username" : username,
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
  
  
  static func logStoryViewEvent(username: String, storyId: String, name: String, authorName: String, launchType: StoryLaunchType, totalMoments: Int) {
    Answers.logContentView(withName: name, contentType: "Story", contentId: storyId, customAttributes: ["Username" : username,
                                                                                                        "Author Name" : authorName,
                                                                                                        "Launch Type" : launchType.rawValue,
                                                                                                        "Total Moments" : totalMoments])
  }
  
  
  static func logStoryOwnViewEvent(username: String, launchType: StoryLaunchType) {
    Answers.logCustomEvent(withName: "Story Own", customAttributes: ["Username" : username,
                                                                     "Launch Type" : launchType])
  }
  
  
  static func logStoryExitEvent(username: String,
                                storyId: String,
                                name: String,
                                storyPercentage: Double,
                                authorName: String,
                                momentId: String,
                                momentNumber: Int,
                                totalMoments: Int,
                                videoPercentage: Double) {
    
    Answers.logCustomEvent(withName: "Story Exit", customAttributes: ["Username" : username,
                                                                      "Story ID" : storyId,
                                                                      "Story Name" : name,
                                                                      "Story Percentage" : storyPercentage,
                                                                      "Author Name" : authorName,
                                                                      "Moment ID" : momentId,
                                                                      "Moment Number" : momentNumber,
                                                                      "Total Moments" : totalMoments,
                                                                      "Video %" : videoPercentage])
  }
  
  
  static func logStoryLikedEvent(username: String,
                                 authorName: String,
                                 storyPercentage: Double,
                                 momentId: String,
                                 momentNumber: Int,
                                 totalMoments: Int,
                                 mediaType: FoodieMediaType,
                                 storyId: String,
                                 storyName: String) {
    
    Answers.logCustomEvent(withName: "Story Liked", customAttributes: ["Username" : username,
                                                                       "Author Name" : authorName,
                                                                       "Story Percentage" : storyPercentage,
                                                                       "Moment ID" : momentId,
                                                                       "Moment Number" : momentNumber,
                                                                       "Total Moments" : totalMoments,
                                                                       "Media Type" : mediaType.rawValue,
                                                                       "Story ID" : storyId,
                                                                       "Story Name" : storyName])
  }
  
  
  static func logStorySwipeEvent(username: String,
                                 url: String,
                                 message: String,
                                 storyPercentage: Double,
                                 momentId: String,
                                 momentNumber: Int,
                                 totalMoments: Int,
                                 mediaType: FoodieMediaType,
                                 storyId: String,
                                 storyName: String,
                                 authorName: String) {
    
    Answers.logCustomEvent(withName: "Story Swiped", customAttributes: ["Username" : username,
                                                                         "URL" : url,
                                                                         "Message" : message,
                                                                         "Story Percentage" : storyPercentage,
                                                                         "Moment ID" : momentId,
                                                                         "Moment Number" : momentNumber,
                                                                         "Total Moments" : totalMoments,
                                                                         "Media Type" : mediaType.rawValue,
                                                                         "Story ID" : storyId,
                                                                         "Story Name" : storyName,
                                                                         "Author Name" : authorName])
  }
  
  
  static func logStoryVenueEvent(username: String,
                                 venueId: String,
                                 venueName: String,
                                 storyPercentage: Double,
                                 momentId: String,
                                 momentNumber: Int,
                                 totalMoments: Int,
                                 mediaType: FoodieMediaType,
                                 storyId: String,
                                 storyName: String,
                                 authorName: String) {
    
    Answers.logCustomEvent(withName: "Venue Clicked", customAttributes: ["Username" : username,
                                                                         "Venue ID" : venueId,
                                                                         "Venue Name" : venueName,
                                                                         "Story Percentage" : storyPercentage,
                                                                         "Moment ID" : momentId,
                                                                         "Moment Number" : momentNumber,
                                                                         "Total Moments" : totalMoments,
                                                                         "Media Type" : mediaType.rawValue,
                                                                         "Story ID" : storyId,
                                                                         "Story Name" : storyName,
                                                                         "Author Name" : authorName])
    
  }
  
  
  static func logStoryProfileEvent(username: String,
                                   authorName: String,
                                   storyPercentage: Double,
                                   momentId: String,
                                   momentNumber: Int,
                                   totalMoments: Int,
                                   mediaType: FoodieMediaType,
                                   storyId: String,
                                   storyName: String) {
    
    Answers.logCustomEvent(withName: "Profile Clicked", customAttributes: ["Username" : username,
                                                                           "Author Name" : authorName,
                                                                           "Story Percentage" : storyPercentage,
                                                                           "Moment ID" : momentId,
                                                                           "Moment Number" : momentNumber,
                                                                           "Total Moments" : totalMoments,
                                                                           "Media Type" : mediaType.rawValue,
                                                                           "Story ID" : storyId,
                                                                           "Story Name" : storyName])
    
  }
  
  
  static func logBookmarkEvent(username: String,
                               authorName: String,
                               storyPercentage: Double,
                               momentId: String,
                               momentNumber: Int,
                               totalMoments: Int,
                               mediaType: FoodieMediaType,
                               storyId: String,
                               storyName: String) {
    
    Answers.logCustomEvent(withName: "Story Bookmarked", customAttributes: ["Username" : username,
                                                                            "Author Name" : authorName,
                                                                            "Story Percentage" : storyPercentage,
                                                                            "Moment ID" : momentId,
                                                                            "Moment Number" : momentNumber,
                                                                            "Total Moments" : totalMoments,
                                                                            "Media Type" : mediaType.rawValue,
                                                                            "Story ID" : storyId,
                                                                            "Story Name" : storyName])
  }
  
  
  // MARK: - Composition Events
  
  static func logCameraPhotoEvent(username: String) {
    Answers.logCustomEvent(withName: "Photo Captured", customAttributes: ["Username" : username])
  }
  
  static func logCameraVideoEvent(username: String, duration: Double) {
    Answers.logCustomEvent(withName: "Video Captured", customAttributes: ["Username" : username, "Duration" : duration])
  }

  static func logPickerPhotoEvent(username: String, width: Double, aspectRatio: Double) {
    Answers.logCustomEvent(withName: "Photo Picked", customAttributes: ["Username" : username, "Width" : width,
                                                                        "Aspect Ratio" : "\(aspectRatio.truncate(places: 1))"])
  }
  
  static func logPickerVideoEvent(username: String, width: Double, aspectRatio: Double, duration: Double) {
    Answers.logCustomEvent(withName: "Video Picked", customAttributes: ["Username" : username, "Width" : width,
                                                                        "Aspect Ratio" : "\(aspectRatio.truncate(places: 1))",
                                                                        "Duration" : duration])
  }
  
  static func logStoryPosted(authorName: String, storyId: String, totalMoments: Int) {
    Answers.logCustomEvent(withName: "Story Posted", customAttributes: ["Author Name" : authorName,
                                                                        "Story ID" : storyId,
                                                                        "Total Moments" : totalMoments])
  }
  
  static func logStoryEditAttempted(authorName: String, storyId: String) {
    Answers.logCustomEvent(withName: "Story Edit Attempted", customAttributes: ["Author Name" : authorName,
                                                                                "Story ID" : storyId])
  }
  
  static func logStoryEditSaved(authorName: String, storyId: String) {
    Answers.logCustomEvent(withName: "Story Edit Saved", customAttributes: ["Author Name" : authorName,
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
  
  
  // MARK: - Sharing Events
  
  enum ShareContentType: String {
    case story
    case userProfile
    case venueProfile
  }
  
  static func logShareEvent(contentType: ShareContentType, username: String, objectId: String, name: String) {
    Answers.logCustomEvent(withName: "Content Shared", customAttributes: ["Content Type" : contentType.rawValue,
                                                                          "Username" : username,
                                                                          "Object ID" : objectId,
                                                                          "Name" : name])
  }

}
