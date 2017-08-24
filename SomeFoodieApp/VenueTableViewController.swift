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
  func venueSearchComplete(venueID: String, venueName: String) // I don't think we need anything else passed back?
}


class VenueTableViewController: UIViewController {
  
  // MARK: - Types & Enumerations
  
  // MARK: - Public Instance Variables
  var delegate: VenueTableReturnDelegate?
  var venueID: String?
  var venueName: String?
  var suggestedLocation: CLLocation? = nil
  
  
  // MARK: - Private Instance Variables
  fileprivate var venueResultArray: [FoodieVenue]?
  fileprivate var currentLocation: CLLocation? = nil
  fileprivate var nearLocation: String? = nil
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var stackView: UIStackView!  // TODO: Review whether IBOutlets should be Optional or Forced Unwrapped
  @IBOutlet weak var venueSearchBar: UISearchBar!
  @IBOutlet weak var locationSearchBar: UISearchBar!
  @IBOutlet weak var venueTableView: UITableView!
  
  
  // MARK: - IBActions
  @IBAction func rightSwipe(_ sender: UISwipeGestureRecognizer) {
    if let venueID = venueID, let venueName = venueName {
      delegate?.venueSearchComplete(venueID: venueID, venueName: venueName)
    }
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
  
  fileprivate func venueSearchCallback(_ venueArray: [FoodieVenue]?, _ error: Error?) {
    if let error = error {
      DebugPrint.error("Venue Search resulted in error - \(error.localizedDescription)")
      searchErrorDialog()
      return
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
    venueTableView.contentInset = UIEdgeInsetsMake(stackView.bounds.height, 0.0, 0.0, 0.0)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    DebugPrint.log("JournalViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Search Bar Delegate Protocol Conformance
extension VenueTableViewController: UISearchBarDelegate {
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === venueSearchBar {
      if let venueSearchText = venueSearchBar.text {
        // Search Foursquare based on either
        //  1. the user supplied location
        //  2. the suggested Geolocation
        //  3. the current location
        if let nearLocation = nearLocation {
          FoodieVenue.searchFoursquare(for: venueSearchText, near: nearLocation, withBlock: venueSearchCallback)
        } else if let suggestedLocation = suggestedLocation {
          FoodieVenue.searchFoursquare(for: venueSearchText, at: suggestedLocation, withBlock: venueSearchCallback)
        } else if let currentLocation = currentLocation {
          FoodieVenue.searchFoursquare(for: venueSearchText, at: currentLocation, withBlock: venueSearchCallback)
        } else {
          // Do nothing and save bandwidth?
        }
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
      DebugPrint.error("venueResultArray = nil even tho numberOfRowsInSection = \(tableView.numberOfRows(inSection: indexPath.section))")
      internalErrorDialog()
      cell.textLabel?.text = ""
      return cell
    }
    
    while true {
      if let name = venueResultArray[indexPath.row].name {
        cell.textLabel?.text = name
        break
      } else {
        self.venueResultArray!.remove(at: indexPath.row)
      }
    }
    
    return cell
  }
}


// MARK: - Table View Delegate Protocol Conformance
extension VenueTableViewController: UITableViewDelegate {
  
}


