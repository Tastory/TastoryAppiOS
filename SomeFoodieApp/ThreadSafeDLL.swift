//
//  ThreadSafeDLL.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-08-23.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import Foundation

class ThreadSafeDLL {
  
  
  // MARK: - Classes & Structs
  class Node {
    fileprivate var dll: ThreadSafeDLL?
    fileprivate var prevNode: Node?
    fileprivate var nextNode: Node?
    
    var list: ThreadSafeDLL? { return dll }
    
    var next: Node? {
      guard let dll = dll else {
        DebugPrint.fatal("Cannot get Next Node on Node that doesn't belong to any List!")
      }
      pthread_mutex_lock(&dll.listMutex)
      defer { pthread_mutex_unlock(&dll.listMutex) }
      return nextNode
    }
    
    var prev: Node? {
      guard let dll = dll else {
        DebugPrint.fatal("Cannot get Next Node on Node that doesn't belong to any List!")
      }
      pthread_mutex_lock(&dll.listMutex)
      defer { pthread_mutex_unlock(&dll.listMutex) }
      return prevNode
    }
  }
  
  
  // MARK: - Private Instance Variables
  private var listMutex = pthread_mutex_t()
  private var headNode: Node?
  private var tailNode: Node?
  
  
  // MARK: - Public Instance Variables
  var isEmpty: Bool {
    pthread_mutex_lock(&listMutex)
    defer { pthread_mutex_unlock(&listMutex) }
    return (headNode == nil)
  }
  
  var head: Node? {
    pthread_mutex_lock(&listMutex)
    defer { pthread_mutex_unlock(&listMutex) }
    return headNode
  }
  
  var tail: Node? {
    pthread_mutex_lock(&listMutex)
    defer { pthread_mutex_unlock(&listMutex) }
    return tailNode
  }
 
  
  // MARK: - Private Instance Functions
  private func removeUnsafely(_ node: Node) {
    guard let dll = node.dll else {
      DebugPrint.fatal("Cannot remove a Node that doesn't belong to a list!")
    }
    
    if dll !== self {
      DebugPrint.fatal("Cannot remove a Node that belongs to another list!")
    }
    
    guard let headNode = headNode, let tailNode = tailNode else {
      DebugPrint.fatal("HeadNode/TailNode = nil, unable to proceed")
    }
    
    if node === headNode {
      self.headNode = node.nextNode
    } else if let prevNode = node.prevNode {
      prevNode.nextNode = node.nextNode
    }
    
    if node === tailNode {
      self.tailNode = node.prevNode
    } else if let nextNode = node.nextNode {
      nextNode.prevNode = node.prevNode
    }
    
    node.prevNode = nil
    node.nextNode = nil
    node.dll = nil
  }
  
  
  // MARK: - Public Instance Functions
  func add(toHead node: Node) {
    pthread_mutex_lock(&listMutex)
    
    if node.dll != nil {
      DebugPrint.fatal("Cannot to add a Node that already belongs to another list!")
    }
    node.dll = self
    
    guard let headNode = headNode else {
      self.headNode = node
      self.tailNode = node
      node.prevNode = nil
      node.nextNode = nil
      return
    }
    
    headNode.prevNode = node
    node.nextNode = headNode
    self.headNode = node
    
    pthread_mutex_unlock(&listMutex)
  }
  
  
  func add(toTail node: Node) {
    pthread_mutex_lock(&listMutex)
    
    if node.dll != nil {
      DebugPrint.fatal("Cannot add a Node that already belongs to another list!")
    }
    node.dll = self
    
    guard let tailNode = tailNode else {
      self.headNode = node
      self.tailNode = node
      node.prevNode = nil
      node.nextNode = nil
      return
    }
    
    tailNode.nextNode = node
    node.prevNode = tailNode
    self.tailNode = node
    
    pthread_mutex_unlock(&listMutex)
  }
  
  
  func remove(_ node: Node) {
    pthread_mutex_lock(&listMutex)
    removeUnsafely(node)
    pthread_mutex_unlock(&listMutex)
  }
  
  
  func removeAll() {
    pthread_mutex_lock(&listMutex)
    defer { pthread_mutex_unlock(&listMutex) }
    
    guard let headNode = headNode else { return }
    var thisNode: Node = headNode
    
    while true {
      let nextNode: Node? = thisNode.nextNode
      removeUnsafely(thisNode)
      if nextNode != nil { thisNode = nextNode! } else { break }
    }
  }
  
  
  func convertToArray() -> [Node]? {
    pthread_mutex_lock(&listMutex)
    defer { pthread_mutex_unlock(&listMutex) }
    
    guard let headNode = headNode else { return nil }
    var thisNode: Node = headNode
    var nodeArray = [Node]()
    
    while true {
      let nextNode: Node? = thisNode.nextNode
      nodeArray.append(thisNode)
      if nextNode != nil { thisNode = nextNode! } else { break }
    }
    return nodeArray
  }
}
