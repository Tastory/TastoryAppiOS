//
//  ReputableUser.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-31.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Parse
import Foundation

class ReputableUser: PFObject {
  
}


extension ReputableUser: PFSubclassing {
  static func parseClassName() -> String {
    return "ReputableUser"
  }
}
