//
//  ErrorModel.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-07.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Foundation


class ErrorModel: Error, LocalizedError {
  
  typealias ErrorCode = Int
  
  var error: ErrorModel.ErrorCode  { return privateError }
  var errorDescription: String?
  
  // Private counterpart to the read-only error variable
  private var privateError: ErrorModel.ErrorCode
  
  // This is what needs to be passed in by the thrower
  init (error: ErrorModel.ErrorCode, description: String, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
  
    // This is to fulfill the LocalizedError protocol so Error.localizedDescription will have value
    self.errorDescription = "\(function) - \(description) #file = \(file) #line = \(line)"
    self.privateError = error
    DebugPrint.error(description, function: function, file: file, line: line)
  }
}
