//
//  MomentCollectionViewCell.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-22.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AsyncDisplayKit

protocol MomentCollectionViewCellDelegate: class {
  func deleteMoment(sourceCell cell: MomentCollectionViewCell)
}


class MomentCollectionViewCell: UICollectionViewCell {
  
  // MARK: - Private Static Constants
  private struct Constants {
    static let CellCornerRadius: CGFloat = 5.0
    static let CellShadowColor = UIColor.black
    static let CellShadowOffset = CGSize(width: 0.0, height: 3.0)
    static let CellShadowRadius: CGFloat = 5.0
    static let CellShadowOpacity: Float = 0.25
    
    static let ThumbnailFrameLineWidth: CGFloat = 5.0
    static let AnimationRotateDegrees: CGFloat = 0.5
    static let AnimationTranslateX: CGFloat = 1.0
    static let AnimationTranslateY: CGFloat = 1.0
    static let Count: Int = 1
  }

  
  // MARK: - IBOutlets
  @IBOutlet weak var deleteButton: UIButton!
  
  
  
  
  // MARK: - IBActions
  @IBAction func deleteMomentButton(_ sender: UIButton) {
    delegate?.deleteMoment(sourceCell: self)
  }

  
  
  // MARK: - Public Instance Variable
  var indexPath: IndexPath?
  var thumbImageNode: ASNetworkImageNode
  var activitySpinner: ActivitySpinner!
  var thumbFrameLayer: ThumbnailFrameLayer?
  weak var delegate: MomentCollectionViewCellDelegate?
  
  
  
  // MARK: - Private Instance Functions
  private func degreesToRadians(x: CGFloat) -> CGFloat {
    return CGFloat(Double.pi) * x / 180.0
  }

  
  
  // MARK: - Public Instace Functions
  
  override init(frame: CGRect) {
    thumbImageNode = ASNetworkImageNode()
    super.init(frame: frame)
    
    contentView.addSubview(thumbImageNode.view)
    contentView.sendSubview(toBack: thumbImageNode.view)
    activitySpinner = ActivitySpinner(addTo: contentView)
    
    thumbImageNode.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      thumbImageNode.view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0.0),
      thumbImageNode.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0.0),
      thumbImageNode.view.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 0.0),
      thumbImageNode.view.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: 0.0),
    ])
    
    configureLayers(frame: frame)
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    thumbImageNode = ASNetworkImageNode()
    super.init(coder: aDecoder)
    
    contentView.addSubview(thumbImageNode.view)
    contentView.sendSubview(toBack: thumbImageNode.view)
    activitySpinner = ActivitySpinner(addTo: contentView)
    
    thumbImageNode.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      thumbImageNode.view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0.0),
      thumbImageNode.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0.0),
      thumbImageNode.view.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 0.0),
      thumbImageNode.view.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: 0.0),
    ])
    
    configureLayers(frame: frame)
  }
  
  
  func configureLayers(frame: CGRect) {
    self.layer.masksToBounds = false
    self.layer.cornerRadius = Constants.CellCornerRadius
    self.layer.shadowColor = Constants.CellShadowColor.cgColor
    self.layer.shadowOffset = Constants.CellShadowOffset
    self.layer.shadowRadius = Constants.CellCornerRadius
    self.layer.shadowOpacity = Constants.CellShadowOpacity
    self.layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: layer.cornerRadius).cgPath
    
    thumbImageNode.layer.masksToBounds = true
    thumbImageNode.layer.cornerRadius = Constants.CellCornerRadius
    
    let cellBounds = CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height)
    thumbFrameLayer = ThumbnailFrameLayer(frame: cellBounds)
    thumbFrameLayer!.lineWidth = Constants.ThumbnailFrameLineWidth
    thumbFrameLayer!.cornerRadius = Constants.CellCornerRadius
    thumbFrameLayer!.strokeColor = FoodieGlobal.Constants.ThemeColor.cgColor
    thumbFrameLayer!.isHidden = true
    thumbImageNode.layer.addSublayer(thumbFrameLayer!)
  }

  
  func stopWobble() {
    self.layer.removeAllAnimations()
    self.transform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.AnimationRotateDegrees * 0))
  }

  
  func wobble() {
    let leftOrRight: CGFloat = (Constants.Count % 2 == 0 ? 1 : -1)
    let rightOrLeft: CGFloat = (Constants.Count % 2 == 0 ? -1 : 1)
    let leftWobble: CGAffineTransform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.AnimationRotateDegrees * leftOrRight))
    let rightWobble: CGAffineTransform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.AnimationRotateDegrees * rightOrLeft))
    let moveTransform: CGAffineTransform = leftWobble.translatedBy(x: -Constants.AnimationTranslateX, y: -Constants.AnimationTranslateY)
    let conCatTransform: CGAffineTransform = leftWobble.concatenating(moveTransform)

    transform = rightWobble // starting point

    UIView.animate(withDuration: 0.10, delay: 0.10, options: [.allowUserInteraction, .repeat, .autoreverse], animations: { () -> Void in
      self.transform = conCatTransform
    }, completion: nil)
  }
  
  
  override func prepareForReuse() {
    activitySpinner.remove()
    thumbImageNode.url = nil
    deleteButton.isHidden = true
    thumbFrameLayer?.removeFromSuperlayer()
    thumbFrameLayer = nil
  }
}
