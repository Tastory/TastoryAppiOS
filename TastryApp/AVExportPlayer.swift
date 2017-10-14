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
  
  // MARK: - Error Types Definition
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
  
  
  // MARK: - Private Instance Variable
  private var avURLAsset: AVURLAsset?
  private var avExportSession: AVAssetExportSession?
  private var periodicObserver: Any?
  
  
  // MARK: - Public Instance Variable
  @objc private(set) var avPlayer: AVPlayer?
  private(set) var avExportContext = 0
  
  var delegate: AVPlayAndExportDelegate? {
    didSet {
      if let avPlayerItem = avPlayer?.currentItem {
        if avPlayerItem.isPlaybackLikelyToKeepUp {
          delegate?.avExportPlayer(isLikelyToKeepUp: self)
        } else {
          delegate?.avExportPlayer(isWaitingForData: self)
        }
      }
    }
  }
  
  
  // MARK: - State Change Observers
  @objc private func completedPlaying() {
    delegate?.avExportPlayer(completedPlaying: self)
  }
  
  
  // MARK: - Private Instance Functions
  private func switchBackingToLocalIfNeeded() {
    
    if let avExportSession = avExportSession {
      if avExportSession.status == .completed {
        CCLog.verbose("Switching Backing to Local")
        
        // Swap AVPlayer's backing file to local Cache. It's assumed that the Cache file will always exist if the AVPlayer is still in Memory.
        // If the app quits and a cache clean up occurs, the AVPlayer will get reinitialized next time against the network instead.
        guard let exportURL = avExportSession.outputURL else {
          CCLog.fatal("Unable to get at outputURL. Cannot switch AVPlayer backing to Local File")
        }
        self.initAVPlayer(from: exportURL)
      }
    }
  }
  
  
  // MARK: - Public Instance Functions
  func initAVPlayer(from playURL: URL, with bufferDuration: TimeInterval = 0.0, thru queue: DispatchQueue = DispatchQueue.global(qos: .userInitiated)) {
    avExportSession = nil  // Always clear the export session before re-creating AVURLAsset
    avURLAsset = AVURLAsset(url: playURL)
    avURLAsset!.resourceLoader.setDelegate(self, queue: queue)  // Must be set before the AVURLAsset is first used
    
    // Clean-up the previous instance of AVPlayer first if there was a previous instance
    if let avPlayer = avPlayer {
      NotificationCenter.default.removeObserver(self)
      
      if let periodicObserver = periodicObserver {
        avPlayer.removeTimeObserver(periodicObserver)
        self.periodicObserver = nil
      }
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
    periodicObserver = avPlayer!.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 100), queue: DispatchQueue.main) { [weak self] time in
      if avPlayerItem.isPlaybackLikelyToKeepUp {
        self?.delegate?.avExportPlayer(isLikelyToKeepUp: self!)
      } else {
        self?.delegate?.avExportPlayer(isWaitingForData: self!)
      }
    }
  }
  
  
  func initExportSession(to exportURL: URL, using preset: String = AVAssetExportPreset1280x720, with outputType: AVFileType = .mov) {
    guard let avURLAsset = avURLAsset else {
      CCLog.fatal("avURLAsset == nil. initAVAsset must be called before initExportSession.")
    }
    guard let avAssetExportSession = AVAssetExportSession(asset: avURLAsset, presetName: preset) else {
      CCLog.fatal("Unable to create AVAssetExportSession with URL: \(avURLAsset.url) and Preset: \(preset)")
    }
    avExportSession = avAssetExportSession
    avExportSession!.outputURL = exportURL
    avExportSession!.outputFileType = outputType
    avExportSession!.timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)
  }
  
  
  func exportAsynchronously(withBlock callback: ((Error?) -> Void)?) {
    guard let avExportSession = avExportSession else {
      CCLog.fatal("Unable to exportAsynchornously. avExportSession = nil")
    }
    
    avExportSession.exportAsynchronously {
      switch avExportSession.status {
        
      case .unknown:
        callback?(ErrorCode.exportAsyncStatusUnknownUnexpected)
        
      case .waiting:
        callback?(ErrorCode.exportAsyncStatusWaitingUnexpected)
        
      case .exporting:
        callback?(ErrorCode.exportAsyncStatusExportingUnexpected)
        
      case .completed:
        
        guard let avPlayer = self.avPlayer else {
          CCLog.fatal("avPlayer == nil. Cannot check whether needed to switch AVPlayer backing to Local File")
        }
        guard let avPlayerItem = avPlayer.currentItem else {
          CCLog.fatal("avPlayerItem == nil. Cannot check whether needed to switch AVPlayer backing to Local File")
        }
        if avPlayer.rate == 0.0, CMTimeCompare(avPlayerItem.currentTime(), kCMTimeZero) == 0 {
          // The video is not currently being played, so we can just do the switch now
          self.switchBackingToLocalIfNeeded()
        }
        callback?(nil)
        
      case .failed:
        
        if let error = avExportSession.error {
          let nsError = error as NSError
          if nsError.domain == AVFoundationErrorDomain, nsError.code == AVError.operationInterrupted.rawValue {
            // Operation was interrupted. Lets try to restart
            CCLog.warning("AV Export Asynchronously was Interrupted. Retrying")
            
            guard let exportURL = avExportSession.outputURL else {
              CCLog.warning("AVExportSession OutputURL nil. Retry Failed")
              callback?(avExportSession.error)
              return
            }
            
            self.initExportSession(to: exportURL, using: AVAssetExportPreset1280x720, with: AVFileType.mov)
            self.exportAsynchronously(withBlock: callback)
            return
          }
        }
        callback?(avExportSession.error)
        
      case .cancelled:
        callback?(ErrorCode.exportAsyncCancelled)
      }
    }
  }
  
  
  func cancelExport() {
    guard let avExportSession = avExportSession else {
      CCLog.fatal("No avExportSession to cancel on")
    }
    avExportSession.cancelExport()
  }
    
    
  func layerDisconnected() {
    switchBackingToLocalIfNeeded()
    avPlayer?.pause()
    avPlayer?.seek(to: kCMTimeZero)
  }
    
    
  deinit {
    // This essentially is a Cancel for everything. So let's cancel everything, clean-up, and call it
    guard let avPlayer = avPlayer else {
      CCLog.fatal("avPlayer = nil unexpected")
    }
    if let periodicObserver = periodicObserver {
      avPlayer.removeTimeObserver(periodicObserver)
    }
    NotificationCenter.default.removeObserver(self)
    avExportSession?.cancelExport()
    //removeObserver(self, forKeyPath: #keyPath(avPlayer.currentItem.isPlaybackLikelyToKeepUp))
  }
    
    
  func printStatus() {
    guard let avPlayer = avPlayer else { return }
    
    
    let avPlayerItem = avPlayer.currentItem!
    let avURLAsset = avPlayerItem.asset as! AVURLAsset
    
    CCLog.verbose("")
    CCLog.verbose("avPlayer Status = \(avPlayer.status.rawValue)")
    CCLog.verbose("avPlayer Time Control = \(avPlayer.timeControlStatus.rawValue)")
    
    CCLog.verbose("avPlayerItem Status = \(avPlayerItem.status.rawValue)")
    CCLog.verbose("avPlayerItem Duration = \(avPlayerItem.duration)")
    CCLog.verbose("avPlayerItem LoadedTimeRanges = \(avPlayerItem.loadedTimeRanges as! [CMTimeRange])")
    CCLog.verbose("avPlayerItem currentTime = \(avPlayerItem.currentTime())")
    
    CCLog.verbose("avPlayerItem isPlaybackLikelyToKeepUp = \(avPlayerItem.isPlaybackLikelyToKeepUp)")
    CCLog.verbose("avPlayerItem isPlaybackBufferEmpty = \(avPlayerItem.isPlaybackBufferEmpty)")
    CCLog.verbose("avPlayerItem isPlaybackBufferFull = \(avPlayerItem.isPlaybackBufferFull)")
    
    CCLog.verbose("avAsset isPlayable = \(avURLAsset.isPlayable)")
    CCLog.verbose("avAsset isExportable = \(avURLAsset.isExportable)")
    CCLog.verbose("avAsset isReadable = \(avURLAsset.isReadable)")
    CCLog.verbose("avAsset isCompatibleWithSavedPhotosAlbum = \(avURLAsset.isCompatibleWithSavedPhotosAlbum)")
    
    if let assetCache = avURLAsset.assetCache {
      CCLog.verbose("avAssetCache isPlayableOffline = \(assetCache.isPlayableOffline)")
    } else {
      CCLog.verbose("No Asset Cache")
    }
    
    guard let avExportSession = avExportSession else { return }
    
    CCLog.verbose("avAssetExportSession status = \(avExportSession.status.rawValue)")
    CCLog.verbose("avAssetExportSession progress = \(avExportSession.progress)")
    CCLog.verbose("avAssetExportSession error = \(avExportSession.error?.localizedDescription ?? "No Error")")
    CCLog.verbose("")
  }
}


extension AVExportPlayer: AVAssetResourceLoaderDelegate {
  // Empty Delegate for now. AVAssetExportSession doesn't work if the Resource Loader Delegate is not set
}
