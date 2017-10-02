//
//  StoryMapAnnotation.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-09-09.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit
import MapKit

class StoryMapAnnotation: NSObject, MKAnnotation {
  var title: String?
  let story: FoodieStory
  let coordinate: CLLocationCoordinate2D
  
  init(title: String, story: FoodieStory, coordinate: CLLocationCoordinate2D) {
    self.title = title
    self.story = story
    self.coordinate = coordinate
    
    super.init()
  }
}
