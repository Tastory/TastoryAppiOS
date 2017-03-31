//
//  MarkupVideoViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-30.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import AVFoundation

class MarkupVideoViewController: UIViewController {

  var videoURL: URL?
  var avPlayer = AVPlayer()
  var avPlayerLayer = AVPlayerLayer()
  
  @IBOutlet weak var videoView: UIView?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    //videoURL = URL(string: "https://clips.vorwaert-gmbh.de/big_buck_bunny.mp4")
    
    guard let videoGuardedURL = videoURL else {
      print("DEBUG_PRINT: MarkupVideoViewController.viewDidLoad - Shouldn't be here without a valid videoURL. Asserting")
      fatalError("Shouldn't be here without a valid videoURL")
    }
    avPlayer = AVPlayer(url: videoGuardedURL)
    
    avPlayerLayer = AVPlayerLayer(player: avPlayer)
    
    avPlayerLayer.frame = self.view.bounds
    
    videoView?.layer.addSublayer(avPlayerLayer)
    
    avPlayer.play() // TODO: Make Videos Loop?
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
