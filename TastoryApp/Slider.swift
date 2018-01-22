//
//  Slider.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-22.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit


public enum Orientation {
  case horizontal
  case vertical
}


internal extension Range {
  /// Constrain a `Bound` value by `self`.
  /// Equivalent to max(lowerBound, min(upperBound, value)).
  /// - parameter value: The value to be clamped.
  internal func clamp(_ value: Bound) -> Bound {
    return lowerBound > value ? lowerBound
      : upperBound < value ? upperBound
      : value
  }
}


internal extension UITouch {
  /// Calculate the "progress" of a touch in a view with respect to an orientation.
  /// - parameter view: The view to be used as a frame of reference.
  /// - parameter orientation: The orientation with which to determine the return value.
  /// - returns: The percent across the `view` that the receiver's location is, relative to the `orientation`. Constrained to (0, 1).
  internal func progress(in view: UIView, withOrientation orientation: Orientation) -> CGFloat {
    let touchLocation = self.location(in: view)
    var progress: CGFloat = 0

    switch orientation {
    case .vertical:
      progress = touchLocation.y / view.bounds.height
    case .horizontal:
      progress = touchLocation.x / view.bounds.width
    }

    return (0.0..<1.0).clamp(progress)
  }
}


public class Slider: UIControl {

  var progress: CGFloat {
    didSet {
      centerKnob(at: CGPoint(x: progress * bounds.width, y: progress * bounds.height))
      sendActions(for: .valueChanged)
    }
  }
  
  let trackView: UIView
  let knobView: UIView
  let orientation: Orientation


  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) and storyboard support have been removed, use init(orientation:)")
  }

  
  required public init(orientation: Orientation, initialProgress: CGFloat = 0.0) {
    self.orientation = orientation

    progress = initialProgress
    
    trackView = UIView()
    trackView.backgroundColor = UIColor.white.withAlphaComponent(0.7)
    trackView.isUserInteractionEnabled = false

    trackView.layer.masksToBounds = true
    trackView.layer.borderColor = UIColor.white.cgColor
    trackView.layer.borderWidth = 2

    knobView = UIView()
    knobView.backgroundColor = UIColor.lightGray
    knobView.isUserInteractionEnabled = false
    
    knobView.layer.masksToBounds = true
    knobView.layer.borderColor = UIColor.white.cgColor
    knobView.layer.borderWidth = 3.0
    
    // Outer shadow
    knobView.layer.shadowColor = UIColor.black.cgColor
    knobView.layer.shadowRadius = 3
    knobView.layer.shadowOpacity = 0.2
    knobView.layer.shadowOffset = CGSize(width: 2, height: 2)
    
    super.init(frame: .zero)

    addSubview(trackView)
    addSubview(knobView)
  }

  
  public override func layoutSubviews() {
    super.layoutSubviews()

    trackView.frame = bounds
    let roundedRadius = min(trackView.bounds.width, trackView.bounds.height) / 2.0
    if trackView.layer.cornerRadius != roundedRadius {
      trackView.layer.cornerRadius = roundedRadius
    }

    switch orientation {
    // Set default preview center
    case .horizontal where knobView.center.y != bounds.midY,
         .vertical where knobView.center.x != bounds.midX:
      
      let knobPoint = CGPoint(x: progress * bounds.width, y: progress * bounds.height)
      centerKnob(at: knobPoint)

    // Adjust preview view size if needed
    case .horizontal where autoresizesSubviews:
      knobView.bounds.size = CGSize(width: 25, height: bounds.height + 10)
    case .vertical where autoresizesSubviews:
      knobView.bounds.size = CGSize(width: bounds.width + 10, height: 25)

    default:
      break
    }
    
    let knobRadius = min(knobView.bounds.width, knobView.bounds.height) / 2.0
    if knobView.layer.cornerRadius != knobRadius {
      knobView.layer.cornerRadius = knobRadius
    }
  }
  

  /// Center the preview view at a particular point, given the orientation.
  ///
  /// * If orientation is `.horizontal`, the preview is centered at `(point.x, bounds.midY)`.
  /// * If orientation is `.vertical`, the preview is centered at `(bounds.midX, point.y)`.
  ///
  /// The `x` and `y` values of `point` are constrained to the bounds of the slider.
  /// - parameter point: The desired point at which to center the `knobView`.
  internal func centerKnob(at point: CGPoint) {
    switch orientation {
    case .horizontal:
      let boundedTouchX = (0..<bounds.width).clamp(point.x)
      knobView.center = CGPoint(x: boundedTouchX, y: bounds.midY)
    case .vertical:
      let boundedTouchY = (0..<bounds.height).clamp(point.y)
      knobView.center = CGPoint(x: bounds.midX, y: boundedTouchY)
    }
  }


  /// Begins tracking a touch when the user starts dragging.
  public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    super.beginTracking(touch, with: event)

    progress = touch.progress(in: self, withOrientation: orientation)

    let touchLocation = touch.location(in: self)
    centerKnob(at: touchLocation)

    sendActions(for: .touchDown)
    sendActions(for: .valueChanged)
    return true
  }

  
  /// Continues tracking a touch as the user drags.
  public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    super.continueTracking(touch, with: event)

    progress = touch.progress(in: self, withOrientation: orientation)
    
    if isTouchInside {
      let touchLocation = touch.location(in: self)
      centerKnob(at: touchLocation)
    }

    sendActions(for: .valueChanged)
    return true
  }

  
  /// Ends tracking a touch when the user finishes dragging.
  public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    super.endTracking(touch, with: event)

    guard let endTouch = touch else { return }
    progress = endTouch.progress(in: self, withOrientation: orientation)

    sendActions(for: isTouchInside ? .touchUpInside : .touchUpOutside)
  }

  
  /// Cancels tracking a touch when the user cancels dragging.
  public override func cancelTracking(with event: UIEvent?) {
    sendActions(for: .touchCancel)
  }

  
  /// Increase the tappable area of `Slider` to a minimum of 44 points on either edge.
  override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // Determine the delta between the width / height and 44, the iOS HIG minimum tap target size.
    // If a side is already longer than 44, add 10 points of padding to either side of the slider along that axis.
    let minimumSideLength: CGFloat = 44
    let padding: CGFloat = -20
    let dx: CGFloat = min(bounds.width - minimumSideLength, padding)
    let dy: CGFloat = min(bounds.height - minimumSideLength, padding)

    // If an increased tappable area is needed, respond appropriately
    let increasedTapAreaNeeded = (dx < 0 || dy < 0)
    let expandedBounds = bounds.insetBy(dx: dx / 2, dy: dy / 2)

    if increasedTapAreaNeeded && expandedBounds.contains(point) {
      for subview in subviews.reversed() {
        let convertedPoint = subview.convert(point, from: self)
        if let hitTestView = subview.hitTest(convertedPoint, with: event) {
          return hitTestView
        }
      }
      return self
    } else {
      return super.hitTest(point, with: event)
    }
  }
}


