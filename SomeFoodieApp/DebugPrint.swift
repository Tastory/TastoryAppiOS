//
//  DebugPrint.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-07.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//


class DebugPrint {  // Abstract
  
  // A log entry. You get function, file and line for free
  static func log (_ description: String,
                   function: String = #function,
                   file: String = #file,
                   line: Int = #line)
  {
    print("DEBUG_LOG: \(description)  #file = \(file) #function = \(function) #line = \(line)")
  }


  // This is just a different Log message on Error
  static func error (_ description: String,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line)
  {
    print("DEBUG_ERROR: \(description)  #file = \(file) #function = \(function) #line = \(line)")
  }


  // This will Log and then Assert if in development
  static func assert (_ description: String,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line)
  {
    print("DEBUG_ASSERT: \(description)  #file = \(file) #function = \(function) #line = \(line)")
    assertionFailure("\(description)  #file = \(file) #function = \(function) #line = \(line)")
  }

  
  static func fatal (_ description: String,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line) -> Never
  {
    print("DEBUG_FATAL: \(description)  #file = \(file) #function = \(function) #line = \(line)")
    fatalError("\(description)  #file = \(file) #function = \(function) #line = \(line)")
  }
}
