//
//  UICollectionViewUtil.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 25/04/2021.
//

import UIKit

// MARK: - Utility functions to show custom view with placeholder message
// References : https://stackoverflow.com/questions/43772984/how-to-show-a-message-when-collection-view-is-empty
extension UICollectionView {
  func setEmptyMessage(_ message: String) {
    let messageLabel = UILabel(
      frame: CGRect(
        x: 0,
        y: 0,
        width: self.bounds.size.width,
        height: self.bounds.size.height
      )
    )
    messageLabel.text = message
    messageLabel.textColor = .black
    messageLabel.numberOfLines = 0
    messageLabel.textAlignment = .center
    messageLabel.font = UIFont(name: "TrebuchetMS", size: 20)
    messageLabel.sizeToFit()

    self.backgroundView = messageLabel
  }

  func restore() {
    self.backgroundView = nil
  }
}
