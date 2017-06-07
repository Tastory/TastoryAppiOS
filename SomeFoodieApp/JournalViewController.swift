//
//  JournalViewController.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-04-23.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import AVFoundation

class JournalViewController: UIViewController {
  
  // MARK: - Public Instance Variables
  var viewingJournal: FoodieJournal?
  

  // MARK: - Private Instance Variables
  fileprivate let player = AVQueuePlayer()
  
  fileprivate let USER_FILE_PATH = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
  
  fileprivate var playerLayer: AVPlayerLayer? {
    return playerView.playerLayer
  }
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var playerView: PlayerView!
  
  
  // MARK: - IBActions
  @IBAction func playNextItem(_ sender: Any) {
    player.advanceToNextItem()
  }
  
  @IBAction func backToParent(_ sender: Any) {
    self.dismiss(animated:true, completion:nil)
  }
  
  
  // MARK: - Private Instance Functions
  fileprivate func savePlayedAsset() {
    // cache the viewed video
    let asset:AVURLAsset = player.currentItem?.asset as! AVURLAsset
    let exporter = AVAssetExportSession(asset: asset, presetName:AVAssetExportPresetHighestQuality)
    let fileName = asset.url.lastPathComponent
    let filePath = USER_FILE_PATH
    let outputURL = filePath.appendingPathComponent(fileName)
    
    let manager = FileManager.default
    if(!manager.fileExists(atPath: outputURL.absoluteString)){
      exporter?.outputURL = outputURL
      exporter?.determineCompatibleFileTypes(completionHandler: {(types:[String]) -> Void in
        exporter?.outputFileType = types[0]
        exporter?.exportAsynchronously(completionHandler: {
          
        })
      })
    }
  }
  
  
  // MARK: - Public Instance Functions
  
  func playerItemDidPlayToEndTime() {
    savePlayedAsset()
  }
  
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    playerView.playerLayer.player = player
    var videoAssets = [AVURLAsset]()
    videoAssets.append(AVURLAsset(url: URL(string:"https://s3-us-west-1.amazonaws.com/foodilicious/0A5CC001-1CC0-45E0-A8EC-24F9434EE1CD.mov")!))
    videoAssets.append(AVURLAsset(url: URL(string:"https://s3-us-west-1.amazonaws.com/foodilicious/0755EC5B-F309-4B9B-ACEC-605FC931252D.mov")!))
    videoAssets.append(AVURLAsset(url: URL(string:"https://s3-us-west-1.amazonaws.com/foodilicious/6B683DAF-14EB-4AE8-9D4D-4BEDFDB0E779.mov")!))
    
    for videoAsset in videoAssets
    {
      videoAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
      
      // check if the asset exists in the current cache
      let fileName = videoAsset.url.lastPathComponent
      var fullFilePath = USER_FILE_PATH
      
      fullFilePath.appendPathComponent(fileName)
      
      let manager = FileManager.default
      if(manager.fileExists(atPath: fullFilePath.absoluteString)){
        let fileAsset = AVURLAsset(url:NSURL.fileURL(withPath:fullFilePath.absoluteString))
        player.insert(AVPlayerItem(asset:fileAsset), after: nil)
        player.play()
      }
      else{
        videoAsset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: {
          var error: NSError? = nil
          let status = videoAsset.statusOfValue(forKey: "playable", error: &error)
          switch status {
          case .loaded:
            self.player.insert(AVPlayerItem(asset:videoAsset), after: nil)
            self.player.play()
          case .failed:
            _ = "log an error"
          default: break
            
          }})
      }
    }
    
    NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    
    player.automaticallyWaitsToMinimizeStalling = true
    
    //FoodieJournal.current()
    // Do any additional setup after loading the view.
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    player.pause()
    
    NotificationCenter.default.removeObserver(self)
  }
}


// Delegate for saving videos
extension UIViewController: AVAssetResourceLoaderDelegate{
  
}







