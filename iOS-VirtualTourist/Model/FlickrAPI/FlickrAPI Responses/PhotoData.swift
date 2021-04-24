//
//  PhotoData.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 23/04/2021.
//

import Foundation

struct PhotoData: Codable, Equatable {
  var id: String
  var owner: String
  var secret: String
  var server: String
  var farm: Int
  var title: String
  var isPublic: Int
  var isFriend: Int
  var isFamily: Int

  enum CodingKeys: String, CodingKey {
    case id
    case owner
    case secret
    case server
    case farm
    case title
    case isPublic = "ispublic"
    case isFriend = "isfriend"
    case isFamily = "isfamily"
  }
}
