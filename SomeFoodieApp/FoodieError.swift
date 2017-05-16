//
//  FoodieError.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-07.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import Foundation

class FoodieError: ErrorModel {
  
  enum Code {
    enum User: ErrorModel.ErrorCode {
      case exampleError = 0x100000
    }
    
    enum Object: ErrorModel.ErrorCode {
      case exampleError = 0x200000
    }
    
    enum Category: ErrorModel.ErrorCode {
      case exampleError = 0x300000
    }
    
    enum Eatery: ErrorModel.ErrorCode {
      case exampleError = 0x400000
    }
    
    enum Journal: ErrorModel.ErrorCode {
      case saveSyncParseRethrowGeneric = 0x501000  // Lower 12 bits is the Parse Error Code....? Any value in communicating Framework code up to Controller?
    }
    
    enum Moment: ErrorModel.ErrorCode {
      case setMediaWithPhotoImageNil = 0x601000
      case setMediaWithPhotoJpegRepresentationFailed = 0x602000
    }
    
    enum Markup: ErrorModel.ErrorCode {
      case exampleError = 0x700000
    }
    
    enum History: ErrorModel.ErrorCode {
      case exampleError = 0x800000
    }
  }
}
