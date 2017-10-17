//
//  FoodieFetch.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-06-24.
//  Copyright © 2017 Tastry. All rights reserved.
//


import Foundation


class FoodieFetch {
  
  // MARK: - Constants
  struct Constants {
    static let ConcurrentFetchesAtATime = 3
  }
  
  
  // MARK: - Read Only Static Variable
  private(set) static var global = FoodieFetch()
  
  
  
  // MARK: - Private Instance Variable
  private let fetchQueue = OperationQueue()
  private let operationMutex = SwiftMutex.create()
  private var operationArray = [Operation.QueuePriority: [FoodieOperation]]()
  
  
  
  // MARK: - Private Instance Functions
  
  // !!! This function must be operating inside of Operation Mutex Lock !!!
  private func splitArray(with priority: Operation.QueuePriority, for object: AnyObject) -> [FoodieOperation] {
    guard let operationArray = operationArray[priority] else {
      CCLog.fatal("Operation Array for priority \(priority.rawValue) does not exist")
    }
    var operations = [FoodieOperation]()

    for index in stride(from: operationArray.count - 1, through: 0, by: -1) {
      if operationArray[index].object === object {
        operations.append(operationArray[index])
        self.operationArray[priority]?.remove(at: index)
      }
    }
    return operations
  }
  
  
  // MARK: - Public Instance Functions
  init() {
    operationArray[.high] = [FoodieOperation]()
    operationArray[.low] = [FoodieOperation]()
    fetchQueue.maxConcurrentOperationCount = Constants.ConcurrentFetchesAtATime
  }
  
  
  // Idea here is that each object can at most only have 1 operation per priority
  func queue(_ operation: FoodieOperation, at priority: Operation.QueuePriority) {  // We can later make an intermediary sublcass to make it more diverse across any objects. Eg. Prefetch User Objects, etc
    DispatchQueue.global(qos: .userInitiated).async {
      guard self.operationArray[priority] != nil else {
        CCLog.fatal("Operation Array for priority \(priority.rawValue) does not exist")
      }
      self.operationMutex.lock()
      self.operationArray[priority]!.append(operation)
      let beginCount = self.operationArray[priority]!.count
      self.operationMutex.unlock()
      
      #if DEBUG
        CCLog.info("Added operation to queue priority \(priority.rawValue). Now at \(beginCount) outstanding")
      #else
        CCLog.debug("Added operation to queue priority \(priority.rawValue). Now at \(beginCount) outstanding")
      #endif
      
      operation.queuePriority = priority
      operation.completionBlock = {
        self.operationMutex.lock()
        self.operationArray[priority] = self.operationArray[priority]!.filter { $0 !== operation }
        let endCount = self.operationArray[priority]!.count
        self.operationMutex.unlock()
        
        #if DEBUG
          CCLog.info("Completion recieved for queue priority \(priority.rawValue). Now at \(endCount) outstanding")
        #else
          CCLog.debug("Completion recieved for queue priority \(priority.rawValue). Now at \(endCount) outstanding")
        #endif
      }
      self.fetchQueue.addOperation(operation)
    }
  }
  
  
  func cancel(for object: AnyObject, at priority: Operation.QueuePriority) {
    DispatchQueue.global(qos: .userInitiated).async {
      self.operationMutex.lock()
      let operations = self.splitArray(with: priority, for: object)
      self.operationMutex.unlock()

      if operations.count > 1 {
        CCLog.warning("Not expecting \(operations.count) operations for object in each queue priority")
      }
      else if operations.count == 1 {
        operations[0].cancel()
      }
    }
  }
  
  
  func cancelAllBut(for object: AnyObject, at priority: Operation.QueuePriority) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let operationArray = self.operationArray[priority] else {
        CCLog.fatal("Operation Array for priority \(priority.rawValue) does not exist")
      }

      self.operationMutex.lock()
      let operationsToRemain = self.splitArray(with: priority, for: object)
      let operationsToCancel = operationArray
      self.operationArray[priority] = operationsToRemain
      self.operationMutex.unlock()
      
      for operation in operationsToCancel {
        operation.cancel()
      }
    }
  }
  
  
  func cancelAll(at priority: Operation.QueuePriority) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let operationArray = self.operationArray[priority] else {
        CCLog.fatal("Operation Array for priority \(priority.rawValue) does not exist")
      }
      
      self.operationMutex.lock()
      let operationsToCancel = operationArray
      self.operationArray[priority] = [FoodieOperation]()
      self.operationMutex.unlock()
      
      for operation in operationsToCancel {
        operation.cancel()
      }
    }
  }
}











