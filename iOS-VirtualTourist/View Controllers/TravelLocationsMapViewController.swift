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

  func setUpFetchedResultsController() {
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

  func addAnnotationGestureRecogniser() {
    let longPressGestureRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotation(gestureRecogniser:)))
    longPressGestureRecogniser.minimumPressDuration = 1.0
    // Add gesture to map
    mapView.addGestureRecognizer(longPressGestureRecogniser)
  }

  func getLocationName() -> String {
    var locationName: String = "New Location"
    // Prompt user for location name
    let alertPointName = UIAlertController(title: "New location", message: "Enter a location pin name", preferredStyle: .alert)
    // Actions
    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
      if let setLocationName = alertPointName.textFields?.first?.text {
        locationName = setLocationName
      }
    }
    okAction.isEnabled = false

    alertPointName.addTextField { textField in
      textField.placeholder = "New location name"
      NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: textField, queue: .main) { _ in
        if let text = textField.text, !text.isEmpty {
          okAction.isEnabled = true
        } else {
          okAction.isEnabled = false
        }
      }
    }

    alertPointName.addAction(okAction)
    present(alertPointName, animated: true, completion: nil)

    return locationName
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

  func restoreMap() {
    restoreMapRegion()
    restoreMapLocations()
  }

  func restoreMapRegion() {
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

  func restoreMapLocations() {
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

  func saveAnnotation(annotationToSave: MKAnnotation) {
    let newPin = Pin(context: dataController.viewContext)
    newPin.createdAt = Date()
    newPin.latitude = annotationToSave.coordinate.latitude
    newPin.longitude = annotationToSave.coordinate.longitude
    dataController.saveContext()
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
}

// MARK: - NSFetchedResultsControllerDelegate
extension TravelLocationsMapViewController: NSFetchedResultsControllerDelegate {
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    print(fetchedResultsController.fetchedObjects)
  }
}
