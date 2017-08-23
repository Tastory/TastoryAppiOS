//
//  VenueTableViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-08-12.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
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
  var currentLocation: CLLocation?
  var suggestedLocation: CLLocation?
  
  
  // MARK: - Private Instance Variables
  fileprivate var venueResultArray = [(String, String)]()
  
  
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
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    DebugPrint.log("JournalViewController.didReceiveMemoryWarning")
  }
}


// MARK: - UISearchBar Delegate Protocol Conformance
extension VenueTableViewController: UISearchBarDelegate {
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchBar === venueSearchBar {
      if let venueSearchText = venueSearchBar.text {
        // TODO: Search Foursquare based on either 
        //       1. the user supplied location
        //       2. the suggested Geolocation
        //       3. the current location
        
        //FoodieVenue.searchFoursquare(for: venueSearchText, at: <#T##CLLocation#>, withBlock: <#T##FoodieVenue.VenueErrorBlock?##FoodieVenue.VenueErrorBlock?##([FoodieVenue]?, Error?) -> Void#>)
        
        
        // TODO: Update the table view with the Foursquare provided result
      }
    }
  }
}




