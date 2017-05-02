//
//  ViewEntryController.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-04-23.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import AVFoundation

class ViewEntryController: UIViewController {
    
    let player = AVQueuePlayer()
    
    let USER_FILE_PATH = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
    
    @IBOutlet weak var playerView: PlayerView!
    
    @IBAction func playNextItem(_ sender: Any) {
        player.advanceToNextItem()
    }
    
    @IBAction func backToParent(_ sender: Any) {
        self.dismiss(animated:true, completion:nil)
    }
    
    var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    func savePlayedAsset(){
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
                    
                    print(exporter?.status.rawValue)
                    print(exporter?.error)
                })
            })
        }
    }
    
   
    func playerItemDidPlayToEndTime() {
        savePlayedAsset()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerView.playerLayer.player = player
        var videoAssets = [AVURLAsset]()
        videoAssets.append(AVURLAsset(url: URL(string:"https://d2yt78i54ibg2t.cloudfront.net/IMG_4053.MOV")!))
        videoAssets.append(AVURLAsset(url: URL(string:"https://d2yt78i54ibg2t.cloudfront.net/IMG_4182.MP4")!))
        videoAssets.append(AVURLAsset(url: URL(string:"https://d2yt78i54ibg2t.cloudfront.net/IMG_4208.MOV")!))
        
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
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
}

// Delegate for saving videos
extension UIViewController: AVAssetResourceLoaderDelegate{
    
}
    
    





