//
//  PhotoAlbumViewController.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 24/04/2021.
//

import UIKit
import MapKit
import CoreData

// MARK: - Shows the images downloaded from Flickr for the given selected location
class PhotoAlbumViewController: UIViewController {
  @IBOutlet weak var mapView: MKMapView!

  @IBOutlet weak var photosView: UICollectionView!

  @IBOutlet weak var newCollectionButton: UIButton!

  // The reference pin location whose photos are to be shown
  var pin: Pin!
  // Injected dataController for save/load data from persistent store
  var dataController: DataController!
  // Used to synchronize data operations with collection view
  var fetchedResultsController: NSFetchedResultsController<Photo>!
  // Execute block operation for updating collection view
  var blockOperation = BlockOperation()
  // A count to keep track of the photos downloaded
  var photosDownloadCount: Int = 0

  override func viewDidLoad() {
    super.viewDidLoad()
    setUpFetchedResultsController()
    setUpViews()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setUpFetchedResultsController()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    fetchedResultsController = nil
  }

  private func setUpFetchedResultsController() {
    let photosRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
    let predicate = NSPredicate(format: "pin == %@", pin)
    photosRequest.predicate = predicate
    let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
    photosRequest.sortDescriptors = [sortDescriptor]

    fetchedResultsController = NSFetchedResultsController(
      fetchRequest: photosRequest,
      managedObjectContext: dataController.viewContext,
      sectionNameKeyPath: nil,
      cacheName: nil
    )
    fetchedResultsController.delegate = self

    do {
      try fetchedResultsController.performFetch()
    } catch {
      fatalError("The photos for given pin location could not be fetched: \(error.localizedDescription)")
    }
  }

  private func setUpViews() {
    // create annotation from pin lat, lon
    setUpMapView()
    // check if there are photos for the given pin location
    setUpPhotoAlbumView()
  }

  private func setUpPhotoAlbumView() {
    newCollectionButton.isEnabled = false
    if let pinPhotos = fetchedResultsController.fetchedObjects {
      if pinPhotos.isEmpty {
        photosView.setEmptyMessage("No photos available at the dropped location")
      } else {
        photosDownloadCount = 0
        photosView.restore()
      }
    }
  }

  // MARK: - Show the pin location on the map from its lat and long
  private func setUpMapView() {
    let pinLatitude = CLLocationDegrees(pin.latitude)
    let pinLongitude = CLLocationDegrees(pin.longitude)

    // The lat and long are used to create a CLLocationCoordinates2D instance.
    let annotationCoordinate = CLLocationCoordinate2D(latitude: pinLatitude, longitude: pinLongitude)

    let pinAnnotation = MKPointAnnotation()
    pinAnnotation.coordinate = annotationCoordinate
    // Append to mapView annotations
    mapView.addAnnotation(pinAnnotation)
    // Zoom to show region
    let spanToShow = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    let regionToShow = MKCoordinateRegion(center: annotationCoordinate, span: spanToShow)
    mapView.setRegion(regionToShow, animated: true)
  }

  private func clearPhotoAlbum() {
    // Clear all photos of the given pin
    if let photos = fetchedResultsController.fetchedObjects {
      for photo in photos {
        dataController.viewContext.delete(photo)
        try? dataController.viewContext.save()
      }
    }
  }

  @IBAction func newCollectionTapped(_ sender: Any) {
    // Disable new collection button
    newCollectionButton.isEnabled = false
    photosDownloadCount = 0
    clearPhotoAlbum()
    // Set a random page number from which photos to fetch
    let photosPageToFetch = Int.random(in: Int(pin.page)...Int(pin.pages))
    FlickrClient.getPhotosDataForLocation(
      latitude: self.pin.latitude,
      longitude: self.pin.longitude,
      fetchPhotosOnPage: photosPageToFetch
    ) { photosData, page, pages, _ in
      // Set the current page and total pages of the photos to be displayed
      self.pin.page = Int16(page)
      self.pin.pages = Int16(pages)
      // Add photos from page
      for photoData in photosData {
        let photoDownloadURL = FlickrClient.getPhotoImageURL(
          photoServerId: photoData.server,
          photoId: photoData.id,
          photoSecret: photoData.secret)

        let photoForPin = Photo(context: self.dataController.viewContext)
        photoForPin.createdAt = Date()
        photoForPin.downloadedImageURL = photoDownloadURL
        photoForPin.downloadedImage = nil
        photoForPin.pin = self.pin
      }
      try? self.dataController.viewContext.save()
      self.photosView.reloadData()
    }
  }
}

// MARK: - Delegate for fetched results controller that populates the collection view cells
extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
  // Implementation based on https://knowledge.udacity.com/questions/264616
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    switch type {
    case .insert:
      guard let newIndexPath = newIndexPath else { return }
      blockOperation.addExecutionBlock {
        DispatchQueue.main.async {
          self.photosView.insertItems(at: [newIndexPath])
        }
      }
    case .delete:
      guard let indexPath = indexPath else { return }
      self.photosView.deleteItems(at: [indexPath])
    case .update:
      guard let indexPath = indexPath else { return }
      blockOperation.addExecutionBlock {
        DispatchQueue.main.async {
          self.photosView.reloadItems(at: [indexPath])
        }
      }
    default:
      fatalError("Invalid change type")
    }
  }

  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    let indexSet = IndexSet(integer: sectionIndex)
    switch type {
    case .insert:
      photosView.insertSections(indexSet)
    case .delete:
      photosView.deleteSections(indexSet)
    case .update, .move:
      fatalError("Invalid change type")
    @unknown default:
      fatalError("Unknown change type")
    }
  }
}

// MARK: - Delegate for collection view
extension PhotoAlbumViewController: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return fetchedResultsController.sections?[section].numberOfObjects ?? 0
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let photoAlbumCell = photosView.dequeueReusableCell(
      withReuseIdentifier: "PhotoAlbumViewCell",
      for: indexPath) as! PhotoAlbumViewCell

    let pinPhoto = fetchedResultsController.object(at: indexPath)
    if let photoDownloadedImage = pinPhoto.downloadedImage {
      photoAlbumCell.imageView.image = UIImage(data: photoDownloadedImage)
      self.newCollectionButton.isEnabled = true
    } else {
      // Photo to be downloaded
      // Add placeholder image
      photoAlbumCell.imageView.image = UIImage(named: "image_placeholder")
      if let photoImageURL = pinPhoto.downloadedImageURL {
        DispatchQueue.global(qos: .background).async {
          FlickrClient.downloadPhoto(photoImageURL: photoImageURL) { downloadedImage in
            if let downloadedImage = downloadedImage {
              DispatchQueue.main.async {
                photoAlbumCell.imageView.image = downloadedImage
                pinPhoto.downloadedImage = downloadedImage.jpegData(compressionQuality: 1.0)
                try? self.dataController.viewContext.save()
                // Check here if total images downloaded
                self.photosDownloadCount += 1
                if self.photosDownloadCount == self.fetchedResultsController.fetchedObjects?.count {
                  self.newCollectionButton.isEnabled = true
                }
              }
            }
          }
        }
      }
    }
    return photoAlbumCell
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let photoToDelete = fetchedResultsController.object(at: indexPath)
    dataController.viewContext.delete(photoToDelete)
    try? dataController.viewContext.save()
  }
}

// MARK: - FlowLayoutDelegate for arranging photos of the collection view
extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let itemsPerRow: CGFloat = 3

    let paddingSpace = 10 * (itemsPerRow + 1)
    let availableWidth = self.view.frame.width - paddingSpace
    let widthPerItem = availableWidth / itemsPerRow
    return CGSize(width: widthPerItem, height: widthPerItem)
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsets.zero
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    minimumLineSpacingForSectionAt section: Int
  ) -> CGFloat {
    return 3
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 3
  }
}
