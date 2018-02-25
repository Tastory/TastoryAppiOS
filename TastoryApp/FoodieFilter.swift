//
//  FoodieFilter.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-11.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import Foundation

class FoodieFilter {
  
  // MARK: - Constants
  
  struct Constants {
    static let PriceLowerLimit = 1.0
    static let PriceUpperLimit = 4.0
  }
  
  
  
  // MARK: - Public Static Variables
  
  static var main = FoodieFilter()
  
  
  
  // MARK: - Public Instance Variables
  
  var isDefault: Bool {
    if selectedCategories.count == 0, selectedMealTypes.count == 0,
      priceLowerLimit == Constants.PriceLowerLimit, priceUpperLimit == Constants.PriceUpperLimit {
      return true
    } else {
      return false
    }
  }
  
  
  
  // MARK: - Public Instance Variables
  
  var selectedCategories = [FoodieCategory]()
  var priceLowerLimit = Constants.PriceLowerLimit
  var priceUpperLimit = Constants.PriceUpperLimit
  var selectedMealTypes: [MealType] = []
  
  
  
  // MARK: - Public Instance Functions
  
  func resetAll() {
    selectedCategories = [FoodieCategory]()
    priceLowerLimit = Constants.PriceLowerLimit
    priceUpperLimit = Constants.PriceUpperLimit
    selectedMealTypes = []
  }
}
