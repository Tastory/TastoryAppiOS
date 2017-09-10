//
//  StoryMapAnnotation.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-09.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit
import MapKit

class StoryMapAnnotation: NSObject, MKAnnotation {
  var title: String?
  let journal: FoodieJournal
  let coordinate: CLLocationCoordinate2D
  
  init(title: String, journal: FoodieJournal, coordinate: CLLocationCoordinate2D) {
    self.title = title
    self.journal = journal
    self.coordinate = coordinate
    
    super.init()
  }
}
