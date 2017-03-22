//
//  MKCoordinateSpan+Extensions.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-22.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import MapKit

// Extend the MKCoordinateSpan class so they are comparable
extension MKCoordinateSpan: Comparable, Equatable {
  
  // What I am trying to do here is to get the actual length and width of the conveyed area in KM.
  // In the case where the length and width differs greatly in magnitude, the larger value is of
  // concern, as that seems to be how MapKit will always zoom out to make the longer span fit.
  // Comparison of 2 MKCoordinateSpans instance would then just be the comparison of the greater
  // value on each of the instances
  
  private var latitudeInKm: Double {
    return 110.574*latitudeDelta
  }
  
  private var longitudeInKm: Double {
    return 111.320*cos(latitudeDelta)*longitudeDelta
  }
  
  var greaterValue: Double {
    return latitudeInKm > longitudeInKm ? latitudeInKm : longitudeInKm
  }
  
  public static func < (lhs: MKCoordinateSpan, rhs: MKCoordinateSpan) -> Bool {
    return lhs.greaterValue < rhs.greaterValue
  }
  
  public static func > (lhs: MKCoordinateSpan, rhs: MKCoordinateSpan) -> Bool {
    return lhs.greaterValue > rhs.greaterValue
  }
  
  public static func == (lhs: MKCoordinateSpan, rhs: MKCoordinateSpan) -> Bool {
    return lhs.greaterValue == rhs.greaterValue
  }
}
