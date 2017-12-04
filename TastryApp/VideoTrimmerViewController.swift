//
//  ViewController.swift
//  PryntTrimmerView
//
//  Created by Henry on 27/03/2017.
//  Copyright © 2017 Prynt. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import PryntTrimmerView

protocol VideoTrimmerDelegate {
  func videoTrimmed(from startTime: CMTime, to endTime: CMTime, url assetURL: String)
}

/// A view controller to demonstrate the trimming of a video. Make sure the scene is selected as the initial
// view controller in the storyboard
class VideoTrimmerViewController: UIViewController, UINavigationControllerDelegate  {

    @IBOutlet weak var selectAssetButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var trimmerView: TrimmerView!
    @IBOutlet weak var trimmerBackground: UIView!

    public var avAsset: AVURLAsset?
    public var delegate: VideoTrimmerDelegate?

    var player: AVPlayer?
    var playbackTimeCheckerTimer: Timer?
    var trimmerPositionChangedTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        trimmerView.handleColor = UIColor.white
        trimmerView.mainColor = UIColor.orange
        trimmerBackground.backgroundColor = UIColor.clear.withAlphaComponent(0.6)
    }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let asset = avAsset else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("avAsset is nil")
      }
      return
    }
    loadAsset(asset)
  }

    @IBAction func selectAsset(_ sender: Any) {

      guard let player = player else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("The player is nil.")
        }
        return
      }
      
      player.pause()

      self.dismiss(animated: true) {
        guard let delegate = self.delegate else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("The video trimmer return delegate is nil.")
          }
          return
        }

        guard let startTime = self.trimmerView.startTime else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("The start time is nil")
          }
          return
        }

        guard let endTime = self.trimmerView.endTime else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("The end time is nil")
          }
          return
        }

        guard let asset = self.avAsset else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
            CCLog.fatal("avAsset is nil")
          }
          return
        }

        delegate.videoTrimmed(from: startTime, to: endTime, url:  asset.url.absoluteString)
      }
    }

    @IBAction func cancel(_ sender: Any) {
      guard let player = player else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("The player is nil.")
        }
        return
      }
      player.pause()
      self.dismiss(animated: true, completion: nil)
    }

    @IBAction func play(_ sender: Any) {
        guard let player = player else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
              CCLog.fatal("The player is nil.")
            }
          return
        }

        if !(player.rate != 0 && player.error == nil) {
            player.play()
            playButton.setImage(UIImage(named:"StoryMarkup-PauseButton"), for: .normal)
            startPlaybackTimeChecker()

        } else {
            player.pause()
            playButton.setImage(UIImage(named:"StoryMarkup-PlayButton"), for: .normal)
            stopPlaybackTimeChecker()
        }
    }

    func loadAsset(_ asset: AVAsset) {
        trimmerView.asset = asset
        trimmerView.delegate = self
        addVideoPlayer(with: asset, playerView: playerView)
    }

    private func addVideoPlayer(with asset: AVAsset, playerView: UIView) {
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        NotificationCenter.default.addObserver(self, selector: #selector(VideoTrimmerViewController.itemDidFinishPlaying(_:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)

        let layer: AVPlayerLayer = AVPlayerLayer(player: player)
        layer.backgroundColor = UIColor.white.cgColor
        layer.frame = CGRect(x: 0, y: 0, width: playerView.frame.width, height: playerView.frame.height)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        playerView.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
        playerView.layer.addSublayer(layer)
    }

    @objc func itemDidFinishPlaying(_ notification: Notification) {
        if let startTime = trimmerView.startTime {
            player?.seek(to: startTime)
            player?.play()
        }
    }

    func startPlaybackTimeChecker() {

        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
                                                        selector:
            #selector(VideoTrimmerViewController.onPlaybackTimeChecker), userInfo: nil, repeats: true)
    }

    func stopPlaybackTimeChecker() {

        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }

    @objc func onPlaybackTimeChecker() {

        guard let startTime = trimmerView.startTime, let endTime = trimmerView.endTime, let player = player else {
            return
        }

        let playBackTime = player.currentTime()
        trimmerView.seek(to: playBackTime)

        if playBackTime >= endTime {
            player.seek(to: startTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            trimmerView.seek(to: startTime)
        }
    }
}

extension VideoTrimmerViewController: TrimmerViewDelegate {
    func positionBarStoppedMoving(_ playerTime: CMTime) {
        player?.seek(to: playerTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        player?.play()
        startPlaybackTimeChecker()
    }

    func didChangePositionBar(_ playerTime: CMTime) {
        stopPlaybackTimeChecker()
        player?.pause()
        player?.seek(to: playerTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
}
