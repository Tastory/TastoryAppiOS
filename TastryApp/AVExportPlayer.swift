//
//  AVExportPlayer.swift
//  AVFoundationPlayground
//
//  Created by Howard Lee on 2017-10-12.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AVFoundation


protocol AVPlayAndExportDelegate {

  func avExportPlayer(isLikelyToKeepUp avExportPlayer: AVExportPlayer)
  
  func avExportPlayer(isWaitingForData avExportPlayer: AVExportPlayer)
  
  func avExportPlayer(completedPlaying avExportPlayer: AVExportPlayer)
}


class AVExportPlayer: NSObject {
  
  // MARK: - Constants
  struct Constants {
    static let ExportRetryCount = 5
    static let ExportRetryDelay = 1.0
    static let ExportRetryQoS = DispatchQoS.QoSClass.utility
  }
  
  // MARK: - Error Types
  enum ErrorCode: LocalizedError {
    
    case exportAsyncStatusUnknownUnexpected
    case exportAsyncStatusWaitingUnexpected
    case exportAsyncStatusExportingUnexpected
    case exportAsyncCancelled
    
    var errorDescription: String? {
      switch self {
      case .exportAsyncStatusUnknownUnexpected:
        return NSLocalizedString("Export asynchronously completed with unexpected status of 'Unknown'", comment: "Error description for an exception error code")
      case .exportAsyncStatusWaitingUnexpected:
        return NSLocalizedString("Export asynchronously completed with unexpected status of 'Waiting'", comment: "Error description for an exception error code")
      case .exportAsyncStatusExportingUnexpected:
        return NSLocalizedString("Export asynchronously completed with unexpected status of 'Exporting'", comment: "Error description for an exception error code")
      case .exportAsyncCancelled:
        return NSLocalizedString("Export asynchronously was Cancelled", comment: "Error description for an exception error code")
      }
    }
    
    init(_ errorCode: ErrorCode, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
      self = errorCode
      CCLog.warning(errorDescription ?? "", function: function, file: file, line: line)
    }
  }
  
  
  // MARL: - Private
  private let uniqueIdentifier = UUID().uuidString
  
  
  // MARK: - Private Instance Variable
  private var localURL: URL?
  private var avURLAsset: AVURLAsset?
  private var periodicObserver: Any?
  
  
  // MARK: - Read-Only Instance Variable
  @objc private(set) var avPlayer: AVPlayer?
  private(set) var avExportSession: AVAssetExportSession?
  
  
  // MARK: - Public Instance Variable
  var delegate: AVPlayAndExportDelegate? {
    didSet {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in // This is needed. Because it crashes sometimes when self is removed or something
        self?.determineIfPlaying()
      }
    }
  }
  
  
  // MARK: - State Change Observers
  @objc private func completedPlaying() {
    delegate?.avExportPlayer(completedPlaying: self)
  }
  
  
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    
    guard let keyPath = keyPath else {
      CCLog.warning("No KeyPath for observeValue")
      return
    }
    
    guard object != nil else {
      CCLog.warning("No object for observeValue")
      return
    }
    
    CCLog.debug("Observed Value for keyPath changed - \(keyPath) on AVExport Player \(uniqueIdentifier)")
    
    switch keyPath {
    case #keyPath(AVExportPlayer.avPlayer.currentItem.isPlaybackLikelyToKeepUp), #keyPath(AVExportPlayer.avPlayer.currentItem.isPlaybackBufferEmpty):
      DispatchQueue.main.async {
        CCLog.debug("Determine if playing for AVExport Player \(self.uniqueIdentifier)")
        self.determineIfPlaying()
      }
    
    case #keyPath(AVExportPlayer.avPlayer.status), #keyPath(AVExportPlayer.avPlayer.reasonForWaitingToPlay):
      DispatchQueue.main.async { self.determineIfPlaying() }
      
    default:
      CCLog.warning("No Match for Keypath - \(keyPath)")
      return
    }
  } 
  
  
  // MARK: - Private Instance Functions
  private func determineIfPlaying() {
    if let avPlayer = self.avPlayer, let avPlayerItem = avPlayer.currentItem {
      if avPlayerItem.isPlaybackLikelyToKeepUp {
        delegate?.avExportPlayer(isLikelyToKeepUp: self)
        return
      }
      
      if avPlayerItem.isPlaybackBufferEmpty {
        delegate?.avExportPlayer(isWaitingForData: self)
        return
      }
      
      if avPlayer.status != .readyToPlay {
        delegate?.avExportPlayer(isWaitingForData: self)
        return
      }
      
      if avPlayer.reasonForWaitingToPlay == nil {
        delegate?.avExportPlayer(isLikelyToKeepUp: self)
        return
      }
      
      if let reasonForWaitingToPlay = avPlayer.reasonForWaitingToPlay, reasonForWaitingToPlay == .toMinimizeStalls {
        delegate?.avExportPlayer(isWaitingForData: self)
        return
      }
    }
  }
  
  
  private func switchBackingToLocalIfNeeded() {
    
    if let avExportSession = avExportSession {
      if avExportSession.status == .completed {
        CCLog.verbose("Switching AVAsset URL to completed Output File")
        
        // Swap AVPlayer's backing file to local Cache. It's assumed that the Cache file will always exist if the AVPlayer is still in Memory.
        // If the app quits and a cache clean up occurs, the AVPlayer will get reinitialized next time against the network instead.
        guard let outputURL = avExportSession.outputURL else {
          CCLog.fatal("outputURL = nil. Cannot switch AVPlayer backing to Local File")
        }
        
        guard let localURL = localURL else {
          CCLog.fatal("localURL = nil. Cannot copy exported file from Temp to Local")
        }
        
        do {
          try FileManager.default.copyItem(at: outputURL, to: localURL)
        } catch CocoaError.fileWriteFileExists {
          CCLog.warning("Trying to swich backing when file \(localURL.absoluteString) already exist")
          return  // Just do nothing for now
        } catch {
          CCLog.assert("Failed to copy from \(outputURL.absoluteString) to \(localURL.absoluteString)")
          return
        }
        
        self.initAVPlayer(from: localURL)
      }
    }
  }
  
  
  // MARK: - Public Instance Functions
  func initAVPlayer(from playURL: URL, with bufferDuration: TimeInterval = 0.0, thru queue: DispatchQueue = DispatchQueue.global(qos: .userInitiated)) {
    avExportSession = nil  // Always clear the export session before re-creating AVURLAsset
    avURLAsset = AVURLAsset(url: playURL)
    avURLAsset!.resourceLoader.setDelegate(self, queue: queue)  // Must be set before the AVURLAsset is first used
    
    // Clean-up the previous instance of AVPlayer first if there was a previous instance
    if avPlayer != nil {
      if let avPlayerItem = avPlayer?.currentItem {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: avPlayerItem)
      } else {
        CCLog.assert("AVExportPlayer \(uniqueIdentifier) has no avPlayerItem")
      }
      //TODO saw a crash here before observer might not be registered and there is no way to check in swift
      self.removeObserver(self, forKeyPath: #keyPath(AVExportPlayer.avPlayer.currentItem.isPlaybackLikelyToKeepUp))
      self.removeObserver(self, forKeyPath: #keyPath(AVExportPlayer.avPlayer.currentItem.isPlaybackBufferEmpty))
      self.removeObserver(self, forKeyPath: #keyPath(AVExportPlayer.avPlayer.status))
      self.removeObserver(self, forKeyPath: #keyPath(AVExportPlayer.avPlayer.reasonForWaitingToPlay))
      
//      if let periodicObserver = periodicObserver {
//        avPlayer.removeTimeObserver(periodicObserver)
//        self.periodicObserver = nil
//      }
    }
    
    let avPlayerItem = AVPlayerItem(asset: avURLAsset!)
    avPlayerItem.preferredForwardBufferDuration = bufferDuration
    NotificationCenter.default.addObserver(self, selector: #selector(completedPlaying), name: .AVPlayerItemDidPlayToEndTime, object: avPlayerItem)
    
    avPlayer = AVPlayer(playerItem: avPlayerItem)
    avPlayer!.actionAtItemEnd = .none
    avPlayer!.allowsExternalPlayback = false
    avPlayer!.automaticallyWaitsToMinimizeStalling = true
    avPlayer!.pause()  // Leave this Paused for good measure, until a Layer is added and explicitly plays
    
    // Adding Observers for Starts and Stalls. Queue must be a Serial Queue
//    periodicObserver = avPlayer!.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 2), queue: DispatchQueue.global(qos: .utility)) { [weak self] time in
//      self?.printStatus()
//    }
    
    // Adding Observers for Starts and Stalls
    self.addObserver(self, forKeyPath: #keyPath(avPlayer.currentItem.isPlaybackLikelyToKeepUp), options: [.new], context: nil)
    self.addObserver(self, forKeyPath: #keyPath(avPlayer.currentItem.isPlaybackBufferEmpty), options: [.new], context: nil)
    self.addObserver(self, forKeyPath: #keyPath(avPlayer.status), options: [.new], context: nil)
    self.addObserver(self, forKeyPath: #keyPath(avPlayer.reasonForWaitingToPlay), options: [.new], context: nil)
  }
  

  func exportAsync(to exportURL: URL, thru tempURL: URL, using preset: String = AVAssetExportPreset960x540, with outputType: AVFileType = .mov, completion callback: ((Error?) -> Void)? = nil) {
    
    guard let avPlayer = self.avPlayer else {
      CCLog.fatal("avPlayer == nil. Cannot check whether needed to switch AVPlayer backing to Local File")
    }
    guard let avPlayerItem = avPlayer.currentItem else {
      CCLog.fatal("avPlayerItem == nil. Cannot check whether needed to switch AVPlayer backing to Local File")
    }
    guard let avURLAsset = avURLAsset else {
      CCLog.fatal("avURLAsset == nil. initAVAsset must be called before initExportSession.")
    }
    
    localURL = exportURL
    let playURL = avURLAsset.url
    
    let exportRetry = SwiftRetry()
    exportRetry.start("AVExport Sync to \(playURL.lastPathComponent)", withCountOf: Constants.ExportRetryCount) { [unowned self] in
      guard let avAssetExportSession = AVAssetExportSession(asset: avURLAsset, presetName: preset) else {
        CCLog.fatal("Unable to create AVAssetExportSession with URL: \(playURL) and Preset: \(preset)")
      }
      CCLog.verbose("Starting AVExport Asynchronously from \(playURL.absoluteString) to \(exportURL.absoluteString)")

      avAssetExportSession.outputURL = tempURL
      avAssetExportSession.outputFileType = outputType
      avAssetExportSession.timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)
      self.avExportSession = avAssetExportSession
      
      avAssetExportSession.exportAsynchronously {
        
        let bufferDuration = avPlayerItem.preferredForwardBufferDuration
        let queue = avURLAsset.resourceLoader.delegateQueue ?? DispatchQueue.global(qos: .userInitiated)
        
        switch avAssetExportSession.status {
          
        case .unknown:
          self.initAVPlayer(from: playURL, with: bufferDuration, thru: queue)
          if !exportRetry.attempt(after: Constants.ExportRetryDelay, withQoS: Constants.ExportRetryQoS) {
            callback?(ErrorCode.exportAsyncStatusUnknownUnexpected)
          }
          
        case .waiting:
          self.initAVPlayer(from: playURL, with: bufferDuration, thru: queue)
          if !exportRetry.attempt(after: Constants.ExportRetryDelay, withQoS: Constants.ExportRetryQoS) {
            callback?(ErrorCode.exportAsyncStatusWaitingUnexpected)
          }
          
        case .exporting:
          self.initAVPlayer(from: playURL, with: bufferDuration, thru: queue)
          if !exportRetry.attempt(after: Constants.ExportRetryDelay, withQoS: Constants.ExportRetryQoS) {
            callback?(ErrorCode.exportAsyncStatusExportingUnexpected)
          }
          
        case .completed:
          if avPlayer.rate == 0.0, CMTimeCompare(avPlayerItem.currentTime(), kCMTimeZero) == 0 {
            // The video is not currently being played, so we can just do the switch now
            self.switchBackingToLocalIfNeeded()
          }
          callback?(nil)
          
        case .failed:
          
          if let error = avAssetExportSession.error {
            
            // Infinite Retries if Interrupted
            let nsError = error as NSError
            if nsError.domain == AVFoundationErrorDomain, nsError.code == AVError.operationInterrupted.rawValue {
              // Operation was interrupted. Lets try to restart
              CCLog.warning("AV Export Asynchronously was Interrupted. Retrying")
              self.exportAsync(to: exportURL, thru: tempURL, using: preset, with: outputType, completion: callback)
              return
            }
            
            CCLog.warning("ExportAsynchronously Failed - \(error.localizedDescription)")
            if let avAssetURL = (self.avPlayer?.currentItem?.asset as? AVURLAsset)?.url {
              CCLog.warning("AVURLAsset.url = \(avAssetURL.absoluteString)")
            }
            CCLog.warning("OutputURL = \(avAssetExportSession.outputURL?.absoluteString ?? "nil")")
            self.printStatus()
          }
          
          self.initAVPlayer(from: playURL, with: bufferDuration, thru: queue)
          if !exportRetry.attempt(after: Constants.ExportRetryDelay, withQoS: Constants.ExportRetryQoS) {
            callback?(avAssetExportSession.error)
          }
          
        case .cancelled:
          self.avExportSession = nil
          callback?(ErrorCode.exportAsyncCancelled)
        }
      }
    }
  }
  
  
  // Caller should always nil their reference to the avExportPlayer so they know there's no buffer
  func cancelExport() {
    if let avExportSession = avExportSession {
      CCLog.debug("AVExportPlayer.cancelExport")
      guard let avPlayer = avPlayer else {
        CCLog.fatal("No avPlayer to cancel on")
      }
      
      avExportSession.cancelExport()
      avPlayer.pause()
    }
  }
    
    
  func layerDisconnected() {
    switchBackingToLocalIfNeeded()
    avPlayer?.pause()
    avPlayer?.seek(to: kCMTimeZero)
  }
    
    
  deinit {
    // This essentially is a Cancel for everything. So let's cancel everything, clean-up, and call it
    CCLog.verbose("AVExportPlayer Deinit")
//    if let periodicObserver = periodicObserver {
//      avPlayer?.removeTimeObserver(periodicObserver)
//    }
    if let avPlayerItem = avPlayer?.currentItem {
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: avPlayerItem)
    } else {
      CCLog.assert("AVExportPlayer \(uniqueIdentifier) has no avPlayerItem")
    }
    self.removeObserver(self, forKeyPath: #keyPath(avPlayer.currentItem.isPlaybackLikelyToKeepUp))
    self.removeObserver(self, forKeyPath: #keyPath(avPlayer.currentItem.isPlaybackBufferEmpty))
    self.removeObserver(self, forKeyPath: #keyPath(avPlayer.status))
    self.removeObserver(self, forKeyPath: #keyPath(avPlayer.reasonForWaitingToPlay))
    avExportSession?.cancelExport()
    avPlayer?.replaceCurrentItem(with: nil)
  }
    
    
  func printStatus() {
    guard let avPlayer = avPlayer else { return }
    guard let avPlayerItem = avPlayer.currentItem else { return }
    guard let avURLAsset = avPlayerItem.asset as? AVURLAsset else { return }
    
    CCLog.debug("")
    CCLog.debug("avPlayer Status = \(avPlayer.status.string)")
    CCLog.debug("avPlayer Rate = \(avPlayer.rate)")
    CCLog.debug("avPlayer Reason For Waiting to Play = \(avPlayer.reasonForWaitingToPlay?.rawValue ?? "nil")")
    CCLog.debug("avPlayer Time Control = \(avPlayer.timeControlStatus.string)")
    
    CCLog.debug("avPlayerItem Status = \(avPlayerItem.status.string)")
    CCLog.debug("avPlayerItem Duration = \(avPlayerItem.duration)")
    CCLog.debug("avPlayerItem LoadedTimeRanges = \(avPlayerItem.loadedTimeRanges as! [CMTimeRange])")
    CCLog.debug("avPlayerItem currentTime = \(avPlayerItem.currentTime())")
    
    CCLog.debug("avPlayerItem isPlaybackLikelyToKeepUp = \(avPlayerItem.isPlaybackLikelyToKeepUp)")
    CCLog.debug("avPlayerItem isPlaybackBufferEmpty = \(avPlayerItem.isPlaybackBufferEmpty)")
    CCLog.debug("avPlayerItem isPlaybackBufferFull = \(avPlayerItem.isPlaybackBufferFull)")
    
    CCLog.debug("avAsset isPlayable = \(avURLAsset.isPlayable)")
    CCLog.debug("avAsset isExportable = \(avURLAsset.isExportable)")
    CCLog.debug("avAsset isReadable = \(avURLAsset.isReadable)")
    CCLog.debug("avAsset isCompatibleWithSavedPhotosAlbum = \(avURLAsset.isCompatibleWithSavedPhotosAlbum)")
    
    if let assetCache = avURLAsset.assetCache {
      CCLog.debug("avAssetCache isPlayableOffline = \(assetCache.isPlayableOffline)")
    } else {
      CCLog.debug("No Asset Cache")
    }
    
    guard let avExportSession = avExportSession else { return }
    
    CCLog.debug("avAssetExportSession status = \(avExportSession.status.rawValue)")
    CCLog.debug("avAssetExportSession progress = \(avExportSession.progress)")
    CCLog.debug("avAssetExportSession error = \(avExportSession.error?.localizedDescription ?? "nil")")
    CCLog.debug("")
  }
}


extension AVExportPlayer: AVAssetResourceLoaderDelegate {
  // Empty Delegate for now. AVAssetExportSession doesn't work if the Resource Loader Delegate is not set
}
