//
//  VenueTableViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-12.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit
import CoreLocation


protocol VenueTableReturnDelegate {
  func venueSearchComplete(venue: FoodieVenue)
  
  // TODO: - Complete the input and output of data to/from VenueTableViewController
  // 1. Lets put the address of each venue location underneath each
  // 2. Lets make selecting a venue actually pass the venue back to the JournalEntryVC
  // 3. Lets make it so one can pass in a FoodieVenue as a suggested Venue and auto initiate a search
}


class VenueTableViewController: UIViewController {
  
  // MARK: - Types & Enumerations
  
  
  // MARK: - Constants
  struct Constants {
    fileprivate static let defaultLocationPlaceholderText = "Location to search near"
    fileprivate static let searchBarSearchDelay = 0.5
  }
  
  
  // MARK: - Public Instance Variables
  var delegate: VenueTableReturnDelegate?
  var suggestedVenue: FoodieVenue?
  var suggestedLocation: CLLocation?
  
  
  // MARK: - Private Instance Variables
  fileprivate var venueName: String?
  fileprivate var venueResultArray: [FoodieVenue]?
  fileprivate var currentLocation: CLLocation?
  fileprivate var nearLocation: String?
  fileprivate var isVenueSearchUnderWay: Bool = false
  fileprivate var isVenueSearchPending: Bool = false
  fileprivate var searchMutex = SwiftMutex.create()
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var stackView: UIStackView!  // TODO: Review whether IBOutlets should be Optional or Forced Unwrapped
  @IBOutlet weak var venueSearchBar: UISearchBar!
  @IBOutlet weak var locationSearchBar: UISearchBar!
  @IBOutlet weak var venueTableView: UITableView!
  
  
  // MARK: - IBActions
  @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
    dismiss(animated: true, completion: nil)
  }
  
  
  // MARK: - Private Instance Functions
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when a Venue Table view internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Venue Table view internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Venue Table errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func searchErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when a Venue Table View search error occurred",
                                              message: "A query error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Venue Table View search error occurred",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Venue Table View errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func locationErrorDialog(message: String, comment: String) {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "EatellyApp",
                                              titleComment: "Alert diaglogue title when a Venue Table View location error occured",
                                              message: message,
                                              messageComment: comment,
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for location related Venue Table View errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  // Working along with venueSearchComplete(), this call is Thread Safe
  func fullVenueSearch() {
    DispatchQueue.global(qos: .userInitiated).async {
      
      // In general, don't have mutexes locking the main thread please
      SwiftMutex.lock(&self.searchMutex)
      guard !self.isVenueSearchUnderWay else {
        self.isVenueSearchPending = true
        SwiftMutex.unlock(&self.searchMutex)
        return
      }
      SwiftMutex.unlock(&self.searchMutex)
      
      // Search Foursquare based on either
      //  1. the user supplied location
      //  2. the suggested Geolocation
      //  3. the current location
      var venueNameToSearch = ""
      if let venueName = self.venueName {
        venueNameToSearch = venueName
      }
      if let nearLocation = self.nearLocation {
        FoodieVenue.searchFoursquare(for: venueNameToSearch, near: nearLocation, withBlock: self.venueSearchCallback)
      } else if let suggestedLocation = self.suggestedLocation {
        FoodieVenue.searchFoursquare(for: venueNameToSearch, at: suggestedLocation, withBlock: self.venueSearchCallback)
      } else if let currentLocation = self.currentLocation {
        FoodieVenue.searchFoursquare(for: venueNameToSearch, at: currentLocation, withBlock: self.venueSearchCallback)
      } else {
        CCLog.warning("No useful location to base the search on")
        AlertDialog.present(from: self, title: "Cannot Determine Location", message: "Please enter a location to perform Venue Search")
        self.locationSearchBar.placeholder = Constants.defaultLocationPlaceholderText
        self.locationSearchBar.setNeedsDisplay()
      }
    }
  }
  
  fileprivate func venueSearchCallback(_ venueArray: [FoodieVenue]?, _ geocode: FoodieVenue.Geocode?, _ error: Error?) {
    
    // Error Handle First
    if let error = error as? FoodieVenue.ErrorCode {
      switch error {
      case .searchFoursquareFailedGeocode:
        AlertDialog.present(from: self, title: "Cannot find Location", message: "Please input a valid location, or leave location field empty")
      default:
        AlertDialog.present(from: self, title: "Venue Search Failed", message: "Please try another venue name or location")
      }
      return
    }
    
    DispatchQueue.main.async {
      // Update actual search Location if Geocode response available
      if let geocode = geocode, let displayName = geocode.displayName {
        self.locationSearchBar.text = displayName
        self.nearLocation = displayName
      } else {
        self.locationSearchBar.text = ""
        self.nearLocation = nil
      }
      
      guard let venueArray = venueArray else {
        // Just make sure venueResultArray is cleared
        self.venueResultArray = nil
        self.venueTableView.reloadData()
        return
      }
      
      self.venueResultArray = venueArray
      self.venueTableView.reloadData()
    }
    
    // If search is pending, make sure another search will be done
    var doAnotherSearch = false
    
    SwiftMutex.lock(&searchMutex)
    isVenueSearchUnderWay = false
    
    if isVenueSearchPending {
      isVenueSearchPending = false
      doAnotherSearch = true
    }
    SwiftMutex.unlock(&searchMutex)
    
    if doAnotherSearch {
      fullVenueSearch()
    }
  }
  
  
  // MARK - Public Instance Functions
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    venueSearchBar.delegate = self
    locationSearchBar.delegate = self
    venueTableView.delegate = self
    venueTableView.dataSource = self
    
    // Update the UI
    if let suggestedVenueName = suggestedVenue?.name {
      venueSearchBar.text = suggestedVenueName
      venueName = suggestedVenueName
    }
    
    if suggestedLocation != nil {
      locationSearchBar.placeholder = "Search near location of Moments"
    } else {
      locationSearchBar.placeholder = Constants.defaultLocationPlaceholderText
    }
    
    // Let's just get location once everytime we enter this screen.
    // Whats the odd of the user moving all the time? Saves some battery
    LocationWatch.global.get { (location, error) in
      if let error = error {
        self.locationErrorDialog(message: "LocationWatch returned error - \(error.localizedDescription)", comment: "Alert Dialogue Message")
        CCLog.warning("LocationWatch returned error - \(error.localizedDescription)")
        return
      }
      
      if let location = location {
        self.currentLocation = location
        
        // A Location suggestion based off the Moment have higher search priority. So only update the placeholder text to reflect this if there is no Suggested Location
        if self.suggestedLocation == nil {
          self.locationSearchBar.placeholder = "Search near Current Location"
          self.locationSearchBar.setNeedsDisplay()
        }
        
        // With the location updated, we can do another search
        self.fullVenueSearch()
      }
    }
    
    // TODO: I think we need to narrow the search categories down a little bit. Aka. also augment FoodieVenue
    // TODO: I think we need to figure out how to deal with Foursquare Category listings
    
    // Kick off an initial search regardless?
    fullVenueSearch()
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    venueSearchBar?.resignFirstResponder()
    locationSearchBar?.resignFirstResponder()
  }
  
  
  override func viewDidLayoutSubviews() {
    venueTableView.contentInset = UIEdgeInsetsMake(stackView.bounds.height, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("JournalViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Search Bar Delegate Protocol Conformance
extension VenueTableViewController: UISearchBarDelegate {
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === venueSearchBar {
      if let venueSearchText = venueSearchBar.text {
        venueName = venueSearchText
        NSObject.cancelPreviousPerformRequests(withTarget: #selector(fullVenueSearch))
        self.perform(#selector(fullVenueSearch), with: nil, afterDelay: Constants.searchBarSearchDelay)
      } else {
        venueName = ""
      }
    }
  }
  
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if searchBar === venueSearchBar {
      fullVenueSearch()
    } else if searchBar === locationSearchBar {
      if let nearText = locationSearchBar.text {
        nearLocation = nearText
        
        if let venueSearchText = venueName, venueSearchText != "" {
          FoodieVenue.searchFoursquare(for: venueSearchText, near: nearText, withBlock: venueSearchCallback)
        } else {
          AlertDialog.present(from: self, title: "No Venue to Search", message: "Please specify a venue name ot search")
        }
      }
    }
  }
  
  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    if searchBar === locationSearchBar {
      if let nearText = locationSearchBar.text, nearText != "" {
        // Just leave it alone
      } else {
        nearLocation = nil
      }
    }
  }

}


// MARK: - Table View Data Source Protocol Conformance
extension VenueTableViewController: UITableViewDataSource {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1  // Hard coded to 1 for now?
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let count = venueResultArray?.count {
      return count
    } else {
      return 0
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "venueTableCell", for: indexPath)
    
    guard let venueResultArray = venueResultArray else {
      CCLog.assert("venueResultArray = nil even tho numberOfRowsInSection = \(tableView.numberOfRows(inSection: indexPath.section))")
      internalErrorDialog()
      cell.textLabel?.text = ""
      cell.detailTextLabel?.text = ""
      return cell
    }
    
    while true {
      // Handle it if we ever removed stuff off the venueResultArray
      if venueResultArray.count <= indexPath.row {
        cell.textLabel?.text = ""
        cell.detailTextLabel?.text = ""
        return cell
      }
      
      let venue = venueResultArray[indexPath.row]
      if let name = venue.name {
        cell.textLabel?.text = name
        
        if let streetAddress = venue.streetAddress, let city = venue.city {
          cell.detailTextLabel?.text = "\(streetAddress), \(city)"
        } else if let streetAddress = venue.streetAddress {
          cell.detailTextLabel?.text = streetAddress
        } else if let city = venue.city {
          cell.detailTextLabel?.text = city
        }
        break
        
      } else {
        // We are not going display venues with no name
        self.venueResultArray!.remove(at: indexPath.row)
        if let id = venue.foursquareVenueID {
          CCLog.warning("Venue with No Name! Venue ID \(id)")
        }
        else {
          CCLog.warning("Venue with No Name and No Venue ID either!!")
        }
      }
    }
    return cell
  }
}


// MARK: - Table View Delegate Protocol Conformance
extension VenueTableViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let venueResultArray = venueResultArray else {
      CCLog.assert("venueResultArray = nil not expected when user didSelectRowAt \(indexPath.row)")
      internalErrorDialog()
      return
    }
    
    // Call the delegate's function for returning the venue
    delegate?.venueSearchComplete(venue: venueResultArray[indexPath.row])
    dismiss(animated: true, completion: nil)
  }
  
  // Hide the keyboard if the venue table begins dragging
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    venueSearchBar?.resignFirstResponder()
    locationSearchBar?.resignFirstResponder()
  }
}


