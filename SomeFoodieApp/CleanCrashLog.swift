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
    #else
    private let stdoutMinSeverity = LogSeverity.debug
    #endif
    fileprivate static let rotatingMinSeverity = LogSeverity.debug
    fileprivate static let osLogMinSeverity = LogSeverity.info
    fileprivate static let crashlyticsLogMinSeverity = LogSeverity.info
  }
  
  
  // MARK: - Public Static Functions
  static func initializeLogging() {
    
    var configs = [LogConfiguration]()
    
    // For Debug, consider adding Filters. See CleanroomLogger documentation on LogFilter
    
    // Create a recorder for logging to stdout & stderr and add a configuration that references it
    let stderr = StandardStreamsLogRecorder(formatters: [XcodeLogFormatter()])
    configs.append(BasicLogConfiguration(minimumSeverity: Constant.stdoutMinSeverity, recorders: [stderr]))
    
    // Create a configuration for a 15-day rotating log directory
    let fileCfg = RotatingLogFileConfiguration(minimumSeverity: Constant.rotatingMinSeverity,
                                               daysToKeep: 15,
                                               directoryPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("CleanCrashLog"),
                                               formatters: [ParsableLogFormatter(timestampStyle: .default)])
    
    // Crash if the log directory doesn’t exist yet & can’t be created
    try! fileCfg.createLogDirectory()
    configs.append(fileCfg)
    
    // Create a recorder for logging via OSLog (if possible) and add a configuration that references it
//    if let osLog = OSLogRecorder(formatters: [ReadableLogFormatter()]) {
//      // the OSLogRecorder initializer will fail if running on a platform that doesn’t support the os_log() function
//      configs.append(BasicLogConfiguration(minimumSeverity: Constant.osLogMinSeverity, recorders: [osLog]))
//    }
    
    // Create a recorder for logging into Crashlytics
    let crashlyticsLog = CrashlyticsLogRecorder(formatters: [ParsableLogFormatter(timestampStyle: .default)])
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
      assertionFailure("\(description), \(file), \(function), \(line)")  // Wait for logging to flush before Asserting
    }
    sleep(3)  // This just merely prevents this thread from proceeding, but also relinquish processor resources to other threads
    #endif
  }

  // This is Fatal and will never return, Development or Production
  static func fatal(_ description: String, function: String = #function, file: String = #file, line: Int = #line) -> Never {
    Log.error?.message(description, function: function, filePath: file, fileLine: line)
    sleep(3) // Sleep this thread and wait for logging to flush before going Fatal
    fatalError("\(description), \(file), \(function), \(line)")
  }
}


// MARK: - Defining Custom Log Recorder for Crashlytics Log & Error Reporting
class CrashlyticsLogRecorder: LogRecorderBase
{
  override func record(message: String, for entry: LogEntry, currentQueue: DispatchQueue, synchronousMode: Bool) {
    CLSLogv("%@", getVaList([message]))  // As suggested at the bottom of https://stackoverflow.com/questions/28054329/how-to-use-crashlytics-logging-in-swift
  }
}
