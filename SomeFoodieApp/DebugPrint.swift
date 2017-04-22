//
//  DebugPrint.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-07.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//


class DebugPrint {  // Abstract
  
  // A log entry. You get function, file and line for free  // TODO: Add Logging severity? Make Logs filterable?
  static func log (_ description: String,
                   function: String = #function,
                   file: String = #file,
                   line: Int = #line)
  {
    print("DEBUG_LOG: \(description)  #file = \(file) #function = \(function) #line = \(line)")
  }

  // Log Entry for User Action
  static func userAction (_ description: String,
                          function: String = #function,
                          file: String = #file,
                          line: Int = #line)
  {
    print("DEBUG_USER_ACTION: \(description)  #file = \(file) #function = \(function) #line = \(line)")
  }
  
  
  // Log Entry for User Error
  static func userError (_ description: String,
                         function: String = #function,
                         file: String = #file,
                         line: Int = #line)
  {
    print("DEBUG_USER_ERROR: \(description)  #file = \(file) #function = \(function) #line = \(line)")
  }

  
  // Log Entry on real Error Paths
  static func error (_ description: String,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line)
  {
    print("DEBUG_ERROR: \(description)  #file = \(file) #function = \(function) #line = \(line)")
  }
  
  
  // This will Log and then Assert if in Development
  static func assert (_ description: String,
                      function: String = #function,
                      file: String = #file,
                      line: Int = #line)
  {
    print("DEBUG_ASSERT: \(description)  #file = \(file) #function = \(function) #line = \(line)")
    assertionFailure("\(description)  #file = \(file) #function = \(function) #line = \(line)")
  }

  
  // This is Fatal and will never return, Development or Production
  static func fatal (_ description: String,
                     function: String = #function,
                     file: String = #file,
                     line: Int = #line) -> Never
  {
    print("DEBUG_FATAL: \(description)  #file = \(file) #function = \(function) #line = \(line)")
    fatalError("\(description)  #file = \(file) #function = \(function) #line = \(line)")
  }
}
