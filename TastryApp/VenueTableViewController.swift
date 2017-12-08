//
//  VenueTableViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-08-12.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import CoreLocation


protocol VenueTableReturnDelegate: class {
  func venueSearchComplete(venue: FoodieVenue)
  
  // TODO: - Complete the input and output of data to/from VenueTableViewController
  // 1. Lets put the address of each venue location underneath each
  // 2. Lets make selecting a venue actually pass the venue back to the StoryEntryVC
  // 3. Lets make it so one can pass in a FoodieVenue as a suggested Venue and auto initiate a search
}


class VenueTableViewController: OverlayViewController {
  
  // MARK: - Types & Enumerations
  
  
  // MARK: - Constants
  private struct Constants {
    static let DefaultLocationPlaceholderText = "Location to search near"
    static let SearchBarSearchDelay = 0.5
    static let StackShadowOffset = FoodieGlobal.Constants.DefaultUIShadowOffset
    static let StackShadowRadius = FoodieGlobal.Constants.DefaultUIShadowRadius
    static let StackShadowOpacity = FoodieGlobal.Constants.DefaultUIShadowOpacity
  }
  
  
  // MARK: - Public Instance Variables
  weak var delegate: VenueTableReturnDelegate?
  var suggestedVenue: FoodieVenue?
  var suggestedLocation: CLLocation?
  
  
  // MARK: - Private Instance Variables
  private var venueName: String?
  private var venueResultArray: [FoodieVenue]?
  private var currentLocation: CLLocation?
  private var nearLocation: String?
  private var isVenueSearchUnderWay: Bool = false
  private var isVenueSearchPending: Bool = false
  private var searchMutex = SwiftMutex.create()
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var stackView: UIStackView!  // TODO: Review whether IBOutlets should be Optional or Forced Unwrapped
  @IBOutlet weak var venueSearchBar: UISearchBar!
  @IBOutlet weak var locationSearchBar: UISearchBar!
  @IBOutlet weak var venueTableView: UITableView!
  
  
  // MARK: - IBActions
  @IBAction func leftBarButtonAction(_ sender: UIButton) {
    popDismiss(animated: true)
  }
  
  
  private func venueSearchCallback(_ venueArray: [FoodieVenue]?, _ geocode: FoodieVenue.Geocode?, _ error: Error?) {
    
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
  // Working along with venueSearchComplete(), this call is Thread Safe
  @objc private func fullVenueSearch() {
    DispatchQueue.main.async {
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
        //AlertDialog.present(from: self, title: "Cannot Determine Location", message: "Please enter a location to perform Venue Search")
        self.locationSearchBar.placeholder = Constants.DefaultLocationPlaceholderText
        self.locationSearchBar.setNeedsDisplay()
      }
    }
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    venueSearchBar.delegate = self
    locationSearchBar.delegate = self
    venueTableView.delegate = self
    venueTableView.dataSource = self
    
    // Update the appearance
    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedStringKey.font.rawValue : UIFont(name: "Raleway-Regular", size: 14)!, NSAttributedStringKey.strokeColor.rawValue : FoodieGlobal.Constants.TextColor]

    // Drop Shadow at the back of the View
    view.layer.masksToBounds = false
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOffset = Constants.StackShadowOffset
    view.layer.shadowRadius = Constants.StackShadowRadius
    view.layer.shadowOpacity = Constants.StackShadowOpacity
    
    // Update the UI
    if let suggestedVenueName = suggestedVenue?.name {
      venueSearchBar.text = suggestedVenueName
      venueName = suggestedVenueName
    }
    
    if suggestedLocation != nil {
      locationSearchBar.placeholder = "Search near location of Moments"
    } else {
      locationSearchBar.placeholder = Constants.DefaultLocationPlaceholderText
    }
    
    // Let's just get location once everytime we enter this screen.
    // Whats the odd of the user moving all the time? Saves some battery
    LocationWatch.global.get { (location, error) in
      if let error = error {
        AlertDialog.standardPresent(from: self, title: .genericLocationError, message: .locationTryAgain)
        CCLog.warning("LocationWatch returned error - \(error.localizedDescription)")
        return
      }
      
      if let location = location {
        self.currentLocation = location
        
        // A Location suggestion based off the Moment have higher search priority. So only update the placeholder text to reflect this if there is no Suggested Location
        if self.suggestedLocation == nil {
          DispatchQueue.main.async {
            self.locationSearchBar.placeholder = "Search near Current Location"
            self.locationSearchBar.setNeedsDisplay()
          }
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
    venueTableView.contentInset = UIEdgeInsetsMake(stackView.bounds.height - UIApplication.shared.statusBarFrame.height, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }

}


// MARK: - Search Bar Delegate Protocol Conformance
extension VenueTableViewController: UISearchBarDelegate {
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === venueSearchBar {
      if let venueSearchText = venueSearchBar.text {
        venueName = venueSearchText
        NSObject.cancelPreviousPerformRequests(withTarget: #selector(fullVenueSearch))
        self.perform(#selector(fullVenueSearch), with: nil, afterDelay: Constants.SearchBarSearchDelay)
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
          FoodieVenue.searchFoursquare(for: "", near: nearText, withBlock: venueSearchCallback)
          //AlertDialog.present(from: self, title: "No Venue to Search", message: "Please specify a venue name ot search")
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("venueResultArray = nil even tho numberOfRowsInSection = \(tableView.numberOfRows(inSection: indexPath.section))")
      }
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("venueResultArray = nil not expected when user didSelectRowAt \(indexPath.row)")
      }
      return
    }
    
    // Call the delegate's function for returning the venue
    delegate?.venueSearchComplete(venue: venueResultArray[indexPath.row])
    popDismiss(animated: true)
  }
  
  // Hide the keyboard if the venue table begins dragging
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    venueSearchBar?.resignFirstResponder()
    locationSearchBar?.resignFirstResponder()
  }
}


