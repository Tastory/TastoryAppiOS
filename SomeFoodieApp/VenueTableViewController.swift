//
//  VenueTableViewController.swift
//  SomeFoodieApp
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
  
  // MARK: - Public Instance Variables
  var delegate: VenueTableReturnDelegate?
  var suggestedVenue: FoodieVenue?
  var suggestedLocation: CLLocation?
  
  
  // MARK: - Private Instance Variables
  fileprivate var venueName: String?
  fileprivate var venueResultArray: [FoodieVenue]?
  fileprivate var currentLocation: CLLocation?
  fileprivate var nearLocation: String?
  //fileprivate var selectedVenue: FoodieVenue?
  
  
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
      let alertController = UIAlertController(title: "SomeFoodieApp",
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
      let alertController = UIAlertController(title: "SomeFoodieApp",
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
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Venue Table View location error occured",
                                              message: message,
                                              messageComment: comment,
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for location related Venue Table View errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func alertErrorDialog(title: String, message: String) {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: title,
                                              titleComment: "Alert diaglogue title when a Venue Table View geocode error occured",
                                              message: message,
                                              messageComment: "Alert diaglogue message when a Venue Table View geocode error occured",
                                              preferredStyle: .alert)
      
      alertController.addAlertAction(title: "OK", comment: "Button in alert dialog box for Venue Table View errors", style: .cancel)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func venueSearchCallback(_ venueArray: [FoodieVenue]?, _ geocode: FoodieVenue.Geocode?, _ error: Error?) {
    
    // Error Handle First
    if let error = error as? FoodieVenue.ErrorCode {
      switch error {
      case .searchFoursquareFailedGeocode:
        alertErrorDialog(title: "Cannot find Location", message: "Please input a valid location, or leave location field empty")
      default:
        searchErrorDialog()
      }
      return
    }
    
    // Update actual search Location if Geocode response available
    if let geocode = geocode, let displayName = geocode.displayName {
      locationSearchBar.text = displayName
      nearLocation = displayName
    } else {
      locationSearchBar.text = ""
      nearLocation = nil
    }
    
    guard let venueArray = venueArray else {
      // Just make sure venueResultArray is cleared
      venueResultArray = nil
      venueTableView.reloadData()
      return
    }
    
    venueResultArray = venueArray
    venueTableView.reloadData()
  }
  
  
  // MARK - Public Instance Functions
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    venueSearchBar.delegate = self
    locationSearchBar.delegate = self
    venueTableView.delegate = self
    venueTableView.dataSource = self
    
    
    // Let's just get location once everytime we enter this screen.
    // Whats the odd of the user moving all the time? Saves some battery
    LocationWatch.global.get { (location, error) in
      if let error = error {
        self.locationErrorDialog(message: "LocationWatch returned error - \(error.localizedDescription)", comment: "Alert Dialogue Message")
        DebugPrint.error("LocationWatch returned error - \(error.localizedDescription)")
        return
      }
      
      if let location = location {
        self.currentLocation = location
      }
    }
    
    // TODO: I think we need to narrow the search categories down a little bit. Aka. also augment FoodieVenue
    // TODO: I think we need to figure out how to deal with Foursquare Category listings
  }
  
  override func viewDidLayoutSubviews() {
    venueTableView.contentInset = UIEdgeInsetsMake(stackView.bounds.height, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    DebugPrint.log("JournalViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Search Bar Delegate Protocol Conformance
extension VenueTableViewController: UISearchBarDelegate {
  
  // MARK: - Private Static Functions
  
  private func fullVenueSearch() {
    // Search Foursquare based on either
    //  1. the user supplied location
    //  2. the suggested Geolocation
    //  3. the current location
    if let venueName = venueName {
      if let nearLocation = nearLocation {
        FoodieVenue.searchFoursquare(for: venueName, near: nearLocation, withBlock: venueSearchCallback)
      } else if let suggestedLocation = suggestedLocation {
        FoodieVenue.searchFoursquare(for: venueName, at: suggestedLocation, withBlock: venueSearchCallback)
      } else if let currentLocation = currentLocation {
        FoodieVenue.searchFoursquare(for: venueName, at: currentLocation, withBlock: venueSearchCallback)
      } else {
        // Do nothing and save bandwidth?
      }
    }
  }
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === venueSearchBar {
      if let venueSearchText = venueSearchBar.text {
        venueName = venueSearchText
        fullVenueSearch()
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
          alertErrorDialog(title: "No Venue to Search", message: "Please specify a venue name ot search")
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
      DebugPrint.assert("venueResultArray = nil even tho numberOfRowsInSection = \(tableView.numberOfRows(inSection: indexPath.section))")
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
      }
    }
    return cell
  }
}


// MARK: - Table View Delegate Protocol Conformance
extension VenueTableViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let venueResultArray = venueResultArray else {
      DebugPrint.assert("venueResultArray = nil not expected when user didSelectRowAt \(indexPath.row)")
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


