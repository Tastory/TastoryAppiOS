//
//  VenueTableViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-08-12.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

protocol VenueTableReturnDelegate {
  func venueSearchComplete(venueID: String) // I don't think we need anything else passed back?
}


class VenueTableViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
