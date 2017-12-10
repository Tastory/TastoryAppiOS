//
//  CategoryTableViewCell
//  TastryApp
//
//  Created by Howard Lee on 2017-09-07.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


protocol CategoryTableViewCellDelegate: class {
  func expandCollpase(for cell: CategoryTableViewCell, to state: CategoryTableViewCell.ExpandCollapseState)
  func selection(for cell: CategoryTableViewCell, to state: FoodieCategory.SelectionState)
}


class CategoryTableViewCell: UITableViewCell {
  
  // MARK: - Enumeration
  enum ExpandCollapseState {
    case expand
    case collapse
  }
  
  
  // MARK: - Public Instance Variable
  weak var delegate: CategoryTableViewCellDelegate?
  var categoryItem: FoodieCategory?
  
  
  // MARK: - Private Instance Variables
  private var state = ExpandCollapseState.collapse
  private var selectionState = FoodieCategory.SelectionState.unselected
  
  
  // MARK: - IBOutlet
  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var expandButton: UIButton!
  @IBOutlet weak var selectRadio: UIButton!
  
  
  // MARK: - IBAction
  @IBAction func expandButtonAction(_ sender: UIButton) {
    switch state {
    case .expand:
      set(to: .collapse, animated: true)
    case .collapse:
      set(to: .expand, animated: true)
    }
    delegate?.expandCollpase(for: self, to: state)
  }
  
  
  @IBAction func radioAction(_ sender: UIButton) {
    switch selectionState {
    case .unselected:
      setRadio(to: .selected)
    case .partial:
      setRadio(to: .unselected)
    case .selected:
      setRadio(to: .unselected)
    }
    delegate?.selection(for: self, to: selectionState)
  }
  
  
  // MARK: - Public Instance Function
  func setRadio(to selectionState: FoodieCategory.SelectionState) {
    switch selectionState {
    case .unselected:
      self.selectionState = .unselected
      selectRadio.setImage(#imageLiteral(resourceName: "Filters-NotSelected"), for: .normal)
      
    case .partial:
      self.selectionState = .partial
      selectRadio.setImage(#imageLiteral(resourceName: "Filters-PartiallySelected"), for: .normal)
      
    case .selected:
      self.selectionState = .selected
      selectRadio.setImage(#imageLiteral(resourceName: "Filters-FullySelected"), for: .normal)
    }
  }
  
  
  func set(to state: ExpandCollapseState, animated: Bool) {
    switch state {
    case .collapse:
      self.state = .collapse
      
      if animated {
        UIView.animate(withDuration: 0.2, animations: {
          self.expandButton.transform = CGAffineTransform.identity
        })
      } else {
        self.expandButton.transform = CGAffineTransform.identity
      }
      
    case .expand:
      self.state = .expand
      
      if animated {
        UIView.animate(withDuration: 0.2, animations: {
          self.expandButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
        })
      } else {
        self.expandButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
      }
    }
  }
}
