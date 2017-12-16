//
//  Analytics.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-12-15.
//  Copyright © 2017 Tastry. All rights reserved.
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
  
  static func loginDiscoverFilter(categoryIDs: [String], priceUpperLimit: Int, priceLowerLimit: Int) {  // Which filters are on?
    Answers.logCustomEvent(withName: "Filter", customAttributes: ["Category IDs" : categoryIDs,
                                                                  "Number of Categories" : categoryIDs.count,
                                                                  "Price Upper Limit" : priceUpperLimit,
                                                                  "Price Lower Limit" : priceLowerLimit])
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
  
  static func logStoryViewEvent(storyId: String, name: String, authorId: String, own: Bool, launchType: StoryLaunchType) {  // From Carousel? Mosaic? Profile? Story ID, Author ID
    Answers.logContentView(withName: name, contentType: "Story", contentId: storyId, customAttributes: ["Author ID" : authorId,
                                                                                                        "Own" : own,
                                                                                                        "Launch Type" : launchType])
  }
  
  static func logStoryExitEvent(storyPercentage: Double, momentId: String, momentNumber: Int, totalMoments: Int) {  // Want to know Percentage on Story Exit, Moment ID & Moment Numbers too
    Answers.logCustomEvent(withName: "Story Exit", customAttributes: ["Percentage" : storyPercentage,
                                                                      "Moment ID" : momentId,
                                                                      "Moment Number" : momentNumber,
                                                                      "Total Moments" : totalMoments])
  }
  
  static func logMomentViewEvent(momentId: String, name: String, storyId: String, authorId: String, authorName: String, own: Bool, momentNumber: Int, totalMoments: Int) {  // Want to know Moment ID
    Answers.logContentView(withName: name, contentType: "Moment", contentId: momentId, customAttributes: ["Moment ID" : momentId,
                                                                                                          "Name" : name,
                                                                                                          "Story ID" : storyId,
                                                                                                          "Author ID" : authorId,
                                                                                                          "Author Name" : authorName,
                                                                                                          "Own" : own,
                                                                                                          "Moment Number" : momentNumber,
                                                                                                          "Total Moments" : totalMoments])
  }
  
  static func logMomentSwipeEvent(url: String,
                                  message: String,
                                  storyPercentage: Double,
                                  momentId: String,
                                  storyId: String,
                                  authorId: String,
                                  authorName: String,
                                  own: Bool,
                                  momentNumber: Int,
                                  totalMoments: Int) {
    
    Answers.logCustomEvent(withName: "Moment Swiped", customAttributes: ["URL" : url,
                                                                        "Message" : message,
                                                                        "Percentage" : storyPercentage,
                                                                        "Moment ID" : momentId,
                                                                        "Story ID" : storyId,
                                                                        "Author ID" : authorId,
                                                                        "Own" : own,
                                                                        "Author Name" : authorName,
                                                                        "Moment Number" : momentNumber,
                                                                        "Total Moments" : totalMoments])
  }
  
  static func logMomentVenueEvent(venueId: String,
                                  venueName: String,
                                  storyPercentage: Double,
                                  momentId: String,
                                  storyId: String,
                                  authorId: String,
                                  authorName: String,
                                  own: Bool,
                                  momentNumber: Int,
                                  totalMoments: Int) {
    
    Answers.logCustomEvent(withName: "Venue Clicked", customAttributes: ["Venue ID" : venueId,
                                                                         "Venue Name" : venueName,
                                                                         "Percentage" : storyPercentage,
                                                                         "Moment ID" : momentId,
                                                                         "Story ID" : storyId,
                                                                         "Author ID" : authorId,
                                                                         "Author Name" : authorName,
                                                                         "Own" : own,
                                                                         "Moment Number" : momentNumber,
                                                                         "Total Moments" : totalMoments])
    
  }
  
  static func logMomentProfileEvent(authorId: String,
                                    authorName: String,
                                    own: Bool,
                                    storyPercentage: Double,
                                    momentId: String,
                                    storyId: String,
                                    momentNumber: Int,
                                    totalMoments: Int) {
    
    Answers.logCustomEvent(withName: "Profile Clicked", customAttributes: ["Author ID" : authorId,
                                                                           "Author Name" : authorName,
                                                                           "Own" : own,
                                                                           "Percentage" : storyPercentage,
                                                                           "Moment ID" : momentId,
                                                                           "Story ID" : storyId,
                                                                           "Moment Number" : momentNumber,
                                                                           "Total Moments" : totalMoments])
    
  }
  
  static func logProfileViewEvent(of id: String, name: String, own: Bool) {
    Answers.logCustomEvent(withName: "Profile Viewed", customAttributes: ["of User ID" : id, "of Username" : name, "Own" : own])
  }
  
  
  // MARK: - Composition Events
  
  static func logCameraPhotoEvent() {
    Answers.logCustomEvent(withName: "Photo Captured", customAttributes: nil)
  }
  
  static func logCameraVideoEvent(duration: Double) {
    Answers.logCustomEvent(withName: "Video Captured", customAttributes: ["Duration" : duration])
  }

  static func logPickerPhotoEvent(width: Int, aspectRatio: Double) {
    Answers.logCustomEvent(withName: "Photo Picked", customAttributes: ["Width" : width,
                                                                        "Aspect Ratio" : aspectRatio])
  }
  
  static func logPickerVideoEvent(width: Int, aspectRatio: Double, duration: Double) {
    Answers.logCustomEvent(withName: "Video Picked", customAttributes: ["Width" : width,
                                                                        "Aspect Ratio" : aspectRatio,
                                                                        "Duration" : duration])
  }
  
  static func logStoryPosted(authorId: String, authorName: String, storyId: String, totalMoments: Int) {
    Answers.logCustomEvent(withName: "Story Posted", customAttributes: ["Author ID" : authorId,
                                                                        "Author Name" : authorName,
                                                                        "Story ID" : storyId,
                                                                        "Total Moments" : totalMoments])
  }
  
  static func logStoryEditAttempted(authorId: String, authorName: String, storyId: String) {
    Answers.logCustomEvent(withName: "Story Edit Attempted", customAttributes: ["Author ID" : authorId,
                                                                                "Author Name" : authorName,
                                                                                "Story ID" : storyId])
  }
  
  static func logStoryEditSaved(authorId: String, authorName: String, storyId: String) {
    Answers.logCustomEvent(withName: "Story Edit Saved", customAttributes: ["Author ID" : authorId,
                                                                            "Author Name" : authorName,
                                                                            "Story ID" : storyId])
  }
}
