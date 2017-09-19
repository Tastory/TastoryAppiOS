//
//  CleanCrashLog.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-04-07.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Fabric
import Crashlytics
import AWSCognito
import CleanroomLogger

class CCLog {
  
  // MARK: - Constants
  struct Constant {
    #if DEBUG
    fileprivate static let stdoutMinSeverity = LogSeverity.verbose
    fileprivate static let rotatingMinSeverity = LogSeverity.debug
    fileprivate static let osLogMinSeverity = LogSeverity.debug
    fileprivate static let crashlyticsLogMinSeverity = LogSeverity.debug
    #else
    fileprivate static let stdoutMinSeverity = LogSeverity.debug
    fileprivate static let rotatingMinSeverity = LogSeverity.debug
    fileprivate static let osLogMinSeverity = LogSeverity.info
    fileprivate static let crashlyticsLogMinSeverity = LogSeverity.info
    #endif
  }
  
  
  // MARK: - Public Static Functions
  static func initializeLogging() {
    
    var configs = [LogConfiguration]()
    let timestampString = "yyyy-MM-dd HH:mm:ss.SSSSSSxx"
    
    // For Debug, consider adding Filters. See CleanroomLogger documentation on LogFilter
    
    // Create a recorder for logging to stdout & stderr and add a configuration that references it
    let stderr = StandardStreamsLogRecorder(formatters: [XcodePlusLogFormatter(timestampString: timestampString)])
    configs.append(BasicLogConfiguration(minimumSeverity: Constant.stdoutMinSeverity, recorders: [stderr]))
    
    // Create a configuration for a 15-day rotating log directory
    let fileCfg = RotatingLogFileConfiguration(minimumSeverity: Constant.rotatingMinSeverity,
                                               daysToKeep: 15,
                                               directoryPath: FoodieFile.Constants.CleanCrashLogFolderUrl.path,
                                               formatters: [ParsableDelimitLogFormatter(delimiterStyle: .spacedPipe, showTimestamp: true)])
    
    // Crash if the log directory doesn’t exist yet & can’t be created
    try! fileCfg.createLogDirectory()
    configs.append(fileCfg)
    
    // Create a recorder for logging via OSLog (if possible) and add a configuration that references it
//    if let osLog = OSLogRecorder(formatters: [ReadableLogFormatter()]) {
//      // the OSLogRecorder initializer will fail if running on a platform that doesn’t support the os_log() function
//      configs.append(BasicLogConfiguration(minimumSeverity: Constant.osLogMinSeverity, recorders: [osLog]))
//    }
    
    // Create a recorder for logging into Crashlytics
    let crashlyticsLog = CrashlyticsLogRecorder(formatters: [ParsableDelimitLogFormatter(delimiterStyle: .spacedPipe, showTimestamp: false)])
    configs.append(BasicLogConfiguration.init(minimumSeverity: Constant.crashlyticsLogMinSeverity, recorders: [crashlyticsLog]))

    // Enable logging using the LogRecorders created above
    Log.enable(configuration: configs)
  }
  
  
  static func initializeReporting() {
    Fabric.with([Crashlytics.self, AWSCognito.self])
    let uuidString = UIDevice.current.identifierForVendor!.uuidString
    Crashlytics.sharedInstance().setUserIdentifier(uuidString)
    info("Device UUID - \(uuidString)")
  }
  
  // TODO: - Consider User Information & Key Value Information on Crash
  
  static func verbose(_ description: String, function: String = #function, file: String = #file, line: Int = #line) {
    Log.verbose?.message(description, function: function, filePath: file, fileLine: line)
  }
  
  static func debug(_ description: String, function: String = #function, file: String = #file, line: Int = #line) {
    Log.debug?.message(description, function: function, filePath: file, fileLine: line)
  }

  static func info(_ description: String, function: String = #function, file: String = #file, line: Int = #line) {
    Log.info?.message(description, function: function, filePath: file, fileLine: line)
  }

  static func warning(_ description: String, function: String = #function, file: String = #file, line: Int = #line) {
    Log.warning?.message(description, function: function, filePath: file, fileLine: line)
  }
  
  // Assertion will halt (crash) on development. Behavior similar to warning on release
  static func assert(_ description: String, function: String = #function, file: String = #file, line: Int = #line) {
    Log.error?.message(description, function: function, filePath: file, fileLine: line)
    #if DEBUG
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
      Crashlytics.sharedInstance().crash()  // Wait for logging to flush before Crashing
      assertionFailure("\(description), \(file), \(function), \(line)")  // This will never get called
    }
    sleep(3)  // This just merely prevents this thread from proceeding, but also relinquish processor resources to other threads
    #endif
  }

  // This is Fatal and will never return, Development or Production
  static func fatal(_ description: String, function: String = #function, file: String = #file, line: Int = #line) -> Never {
    Log.error?.message(description, function: function, filePath: file, fileLine: line)
    sleep(3) // Sleep this thread and wait for logging to flush before going Fatal
    Crashlytics.sharedInstance().crash()
    fatalError("\(description), \(file), \(function), \(line)")  // This won't actually get called
  }
}


// MARK: - Defining Custom Log Recorder for Crashlytics Log & Error Reporting
class CrashlyticsLogRecorder: LogRecorderBase
{
  override func record(message: String, for entry: LogEntry, currentQueue: DispatchQueue, synchronousMode: Bool) {
    CLSLogv("%@", getVaList([message]))  // As suggested at the bottom of https://stackoverflow.com/questions/28054329/how-to-use-crashlytics-logging-in-swift
  }
}


// MARK: - Defining Custom Log Formatter to augment XcodeLogFormatter and ParsableLogFormatter
fileprivate class XcodePlusLogFormatter: LogFormatter {
  
  private let traceFormatter: XcodeTraceLogFormatter
  private let defaultFormatter: FieldBasedLogFormatter
  
  /**
   Initializes a new `XcodeLogFormatter` instance.
   
   - parameter showCallSite: If `true`, the source file and line indicating
   the call site of the log request will be added to formatted log messages.
   */
  public init(showCallSite: Bool = true, timestampString: String? = nil)
  {
    traceFormatter = XcodeTraceLogFormatter()
    
    var fields: [FieldBasedLogFormatter.Field] = []
    var timestampStyle: TimestampStyle = .default
    
    if let timestampString = timestampString {
      timestampStyle = .custom(timestampString)
    }
    
    fields.append(.timestamp(timestampStyle))
    fields.append(.delimiter(.space))
    fields.append(.severity(.xcode))
    fields.append(.delimiter(.space))
    fields.append(.payload)
    
    if showCallSite {
      fields.append(.delimiter(.space))
      fields.append(.delimiter(.custom(" @ ")))
      fields.append(.callSite)
      fields.append(.delimiter(.spacedHyphen))
      fields.append(.stackFrame)
    }
    
    defaultFormatter = FieldBasedLogFormatter(fields: fields)
  }
  
  /**
   Called to create a string representation of the passed-in `LogEntry`.
   
   - parameter entry: The `LogEntry` to attempt to convert into a string.
   
   - returns:  A `String` representation of `entry`, or `nil` if the
   receiver could not format the `LogEntry`.
   */
  open func format(_ entry: LogEntry) -> String?
  {
    return traceFormatter.format(entry) ?? defaultFormatter.format(entry)
  }
}


fileprivate class ParsableDelimitLogFormatter: FieldBasedLogFormatter {
  
  init(delimiterStyle: DelimiterStyle, showTimestamp: Bool) {
    var fields: [FieldBasedLogFormatter.Field] = []
    
    if showTimestamp {
      fields.append(.timestamp(.default))
      fields.append(.delimiter(delimiterStyle))
    }
    
    fields.append(.severity(.numeric))
    fields.append(.delimiter(delimiterStyle))
    
    fields.append(.callingThread(.hex))
    fields.append(.delimiter(delimiterStyle))
    
    fields.append(.callSite)
    fields.append(.delimiter(delimiterStyle))
    
    fields.append(.stackFrame)
    fields.append(.delimiter(delimiterStyle))
    
    fields.append(.payload)
    
    super.init(fields: fields)
  }
}
