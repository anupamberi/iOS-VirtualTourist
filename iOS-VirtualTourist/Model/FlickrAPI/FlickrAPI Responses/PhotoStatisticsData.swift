//
//  PhotosData.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 23/04/2021.
//

import Foundation

struct PhotoStatisticsData: Codable {
  var page: Int
  var pages: Int
  var perpage: Int
  var total: String
  var photo: [PhotoData]
}
