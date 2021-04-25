//
//  ViewController.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 18/04/2021.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController {
  @IBOutlet weak var mapView: MKMapView!

  var dataController: DataController!

  var fetchedResultsController: NSFetchedResultsController<Pin>!

  override func viewDidLoad() {
    super.viewDidLoad()
    setUpFetchedResultsController()
    restoreMap()
    addAnnotationGestureRecogniser()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    fetchedResultsController = nil
  }

  private func setUpFetchedResultsController() {
    let lastMapLocationRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
    let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
    lastMapLocationRequest.sortDescriptors = [sortDescriptor]

    fetchedResultsController = NSFetchedResultsController(fetchRequest: lastMapLocationRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)

    do {
      try fetchedResultsController.performFetch()
    } catch {
      fatalError("The previously added map locations could not be fetched: \(error.localizedDescription)")
    }
  }

  private func addAnnotationGestureRecogniser() {
    let longPressGestureRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotation(gestureRecogniser:)))
    longPressGestureRecogniser.minimumPressDuration = 1.0
    // Add gesture to map
    mapView.addGestureRecognizer(longPressGestureRecogniser)
  }

  @objc func addAnnotation(gestureRecogniser: UIGestureRecognizer) {
    // Do not generate pings many times during long press
    if gestureRecogniser.state != UIGestureRecognizer.State.began {
      return
    }
    // Get coordinates from gesture location
    let touchPoint = gestureRecogniser.location(in: mapView)
    let touchPointCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)

    let annotation = MKPointAnnotation()
    annotation.coordinate = touchPointCoordinates
    mapView.addAnnotation(annotation)
    saveAnnotation(annotationToSave: annotation)
  }

  private func restoreMap() {
    restoreMapRegion()
    restoreMapLocations()
  }

  private func restoreMapRegion() {
    if let lastSavedRegion = UserDefaults.standard.dictionary(forKey: "lastShownRegion") as? [String: Double] {
      // Get latitude, longitude, latitudeDelta & longitudeDelta from save properties
      guard let savedLatitude = lastSavedRegion["latitude"] else { return }
      guard let savedLongitude = lastSavedRegion["longitude"] else { return }
      guard let savedLatitudeDelta = lastSavedRegion["latitudeDelta"] else { return }
      guard let savedLongitudeDelta = lastSavedRegion["longitudeDelta"] else { return }

      let lastSavedCenter = CLLocationCoordinate2D(latitude: savedLatitude, longitude: savedLongitude)
      let lastSavedSpan = MKCoordinateSpan(latitudeDelta: savedLatitudeDelta, longitudeDelta: savedLongitudeDelta)
      let regionToRestore = MKCoordinateRegion(center: lastSavedCenter, span: lastSavedSpan)
      mapView.setRegion(regionToRestore, animated: true)
    }
  }

  private func restoreMapLocations() {
    // Access fetchedObjects
    guard let locationsToRestore = fetchedResultsController.fetchedObjects else {
      return
    }
    for locationToRestore in locationsToRestore {
      let locationToRestoreLatitude = CLLocationDegrees(locationToRestore.latitude)
      let locationToRestoreLongitude = CLLocationDegrees(locationToRestore.longitude)

      // The lat and long are used to create a CLLocationCoordinates2D instance.
      let locationToRestoreCoordinate = CLLocationCoordinate2D(latitude: locationToRestoreLatitude, longitude: locationToRestoreLongitude)

      let locationToRestoreAnnotation = MKPointAnnotation()
      locationToRestoreAnnotation.coordinate = locationToRestoreCoordinate
      locationToRestoreAnnotation.title = locationToRestore.name
      // Append to mapView annotations
      mapView.addAnnotation(locationToRestoreAnnotation)
    }
  }

  private func saveAnnotation(annotationToSave: MKAnnotation) {
    let newPin = Pin(context: dataController.viewContext)
    newPin.createdAt = Date()
    newPin.latitude = annotationToSave.coordinate.latitude
    newPin.longitude = annotationToSave.coordinate.longitude
    // Add photos
    addPinPhotos(pin: newPin)
  }

  private func addPinPhotos(pin: Pin) {
    FlickrClient.getPhotosDataForLocation(
      latitude: pin.latitude,
      longitude: pin.longitude
    ) { photosData, page, pages, _ in
      // Set the current page and total pages of the photos to be displayed
      pin.page = Int16(page)
      pin.pages = Int16(pages)
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
        photoForPin.pin = pin
      }
      try? self.dataController.viewContext.save()
    }
  }
}

// MARK: - MKMapViewDelegate
extension TravelLocationsMapViewController: MKMapViewDelegate {
  // Save the last set location
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    let currentRegion = mapView.region
    // set a dictionary with values to save
    let lastShownRegion = [
      "latitude": currentRegion.center.latitude,
      "longitude": currentRegion.center.longitude,
      "latitudeDelta": currentRegion.span.latitudeDelta,
      "longitudeDelta": currentRegion.span.longitudeDelta
    ]
    UserDefaults.standard.set(lastShownRegion, forKey: "lastShownRegion")
  }

  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let annotation = view.annotation else { return }
    fetchPinFromAnnotation(annotation: annotation) { pin in
      if let fetchedPin = pin {
        print(fetchedPin.latitude)
        print(fetchedPin.longitude)
        let photoAlbumViewController = self.storyboard?.instantiateViewController(identifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
        photoAlbumViewController.pin = fetchedPin
        photoAlbumViewController.dataController = self.dataController
        self.navigationController?.pushViewController(photoAlbumViewController, animated: true)
      }
    }
  }

  func fetchPinFromAnnotation(annotation: MKAnnotation, completion: @escaping (Pin?) -> Void) {
    let pinFetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
    let latitudeNumber = NSNumber(value: annotation.coordinate.latitude)
    let longitudeNumber = NSNumber(value: annotation.coordinate.longitude)

    let latitudePredicate = NSPredicate(format: "latitude == %@", latitudeNumber as CVarArg)
    let longtitudePredicate = NSPredicate(format: "longitude == %@", longitudeNumber as CVarArg)

    let latLongPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [latitudePredicate, longtitudePredicate])
    pinFetchRequest.predicate = latLongPredicate
    let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
    pinFetchRequest.sortDescriptors = [sortDescriptor]

    do {
      let fetchedPins = try dataController.viewContext.fetch(pinFetchRequest)
      completion(fetchedPins.first)
    } catch {
      completion(nil)
    }
  }
}
