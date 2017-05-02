//
//  PlayerView.swift
//  SomeFoodieApp
//
//  Created by Victor Tsang on 2017-04-23.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import AVFoundation

/// A simple `UIView` subclass that is backed by an `AVPlayerLayer` layer.
class PlayerView: UIView {
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

