//
//  MKCoordinateSpan+Extensions.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-22.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import MapKit

// Extend the MKCoordinateSpan class so they are comparable
extension MKCoordinateSpan {

  var height: CLLocationDistance {
    return latitudeDelta*111230
  }
 
  // This creates surface that has the same lat and long degree spans
  init(height: CLLocationDistance) {
    latitudeDelta = height/111230
    longitudeDelta = latitudeDelta/1.78  // TODO: 16:9 aspect ratio assumption is not good enough
  }
}
