//
//  FoodieError.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-07.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//


class FoodieError: ErrorModel {
  
  enum Code {
    enum User: ErrorModel.ErrorCode {
      case exampleError = 0x0100
    }
    
    enum Object: ErrorModel.ErrorCode {
      case exampleError = 0x0200
    }
    
    enum Category: ErrorModel.ErrorCode {
      case exampleError = 0x0300
    }
    
    enum Eatery: ErrorModel.ErrorCode {
      case exampleError = 0x0400
    }
    
    enum Journal: ErrorModel.ErrorCode {
      case exampleError = 0x0500
    }
    
    enum Moment: ErrorModel.ErrorCode {
      case setMediaWithPhotoImageNil = 0x0601
      case setMediaWithPhotoJpegRepresentationFailed
    }
    
    enum Markup: ErrorModel.ErrorCode {
      case exampleError = 0x0701
    }
    
    enum History: ErrorModel.ErrorCode {
      case exampleError = 0x0801
    }
  }
}
