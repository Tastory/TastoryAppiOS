//
//  Double+Extension.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-12-18.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation

extension Double
{
  func truncate(places : Int)-> Double
  {
    return Double(floor(pow(10.0, Double(places)) * self)/pow(10.0, Double(places)))
  }
}
