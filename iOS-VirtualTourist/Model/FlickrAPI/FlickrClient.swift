//
//  FlickrClient.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 21/04/2021.
//
import Foundation
import UIKit
// MARK: - A class to manage all Flickr API interaction and images downloads
class FlickrClient {
  static let apiKey = "83293ec1293edb70071f13043381c97e"

  // MARK: - Returns the photos data along with the pages information
  class func getPhotosDataForLocation(
    latitude: Double,
    longitude: Double,
    fetchPhotosOnPage: Int? = nil,
    completion: @escaping ([PhotoData], Int, Int, Error?) -> Void
  ) {
    guard let flickrPhotoBaseURL = URL(string: "https://www.flickr.com/services/rest/?") else {
      return
    }
    var flickrPhotoSearchURLParams = [
      URLQueryItem(name: "method", value: "flickr.photos.search"),
      URLQueryItem(name: "api_key", value: FlickrClient.apiKey),
      URLQueryItem(name: "lat", value: String(latitude)),
      URLQueryItem(name: "lon", value: String(longitude)),
      URLQueryItem(name: "per_page", value: String(30)),
      URLQueryItem(name: "radius", value: String(0.5)),
      URLQueryItem(name: "format", value: "json"),
      URLQueryItem(name: "nojsoncallback", value: "1")
    ]
    if let fetchPhotosOnPage = fetchPhotosOnPage {
      flickrPhotoSearchURLParams.append(URLQueryItem(name: "page", value: String(fetchPhotosOnPage)))
    }
    guard let flickrPhotosSearchURL = flickrPhotoBaseURL.appending(flickrPhotoSearchURLParams) else { return }
    taskForGETRequest(url: flickrPhotosSearchURL, response: PhotosData.self) { response, error in
      if let response = response {
        completion(response.photos.photo, response.photos.page, response.photos.pages, nil)
      } else {
        completion([], 0, 0, error)
      }
    }
  }

  // MARK: - Construct and return photo image URL from given photo data
  class func getPhotoImageURL(
    photoServerId: String,
    photoId: String,
    photoSecret: String,
    photoSize: String = "q"
  ) -> String {
    return "https://live.staticflickr.com/\(photoServerId)/\(photoId)_\(photoSecret)_\(photoSize).jpg"
  }

  // MARK: - Download the photo image given its URL
  class func downloadPhoto(
    photoImageURL: String,
    completion: @escaping(_ image: UIImage?) -> Void
  ) {
    // Construct the URL from the given photo information
    if let url = URL(string: photoImageURL),
    let imageData = try? Data(contentsOf: url),
    let image = UIImage(data: imageData) {
      completion(image)
    } else {
      completion(nil)
    }
  }

  class func taskForGETRequest<ResponseType: Decodable>(
    url: URL,
    response: ResponseType.Type,
    completion: @escaping (ResponseType?, Error?
    ) -> Void
  ) {
    let task = URLSession.shared.dataTask(with: url) { data, _, error in
      guard let data = data else {
        DispatchQueue.main.async {
          completion(nil, error)
        }
        return
      }
      let decoder = JSONDecoder()
      do {
        let responseObject = try decoder.decode(ResponseType.self, from: data)
        DispatchQueue.main.async {
          completion(responseObject, error)
        }
      } catch {
        completion(nil, error)
      }
    }
    task.resume()
  }
}
