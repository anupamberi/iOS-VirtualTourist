//
//  SceneDelegate.swift
//  iOS-VirtualTourist
//
//  Created by Anupam Beri on 18/04/2021.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  let dataController = DataController(modelName: "VirtualTourist")

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    guard let _ = (scene as? UIWindowScene) else { return }

    dataController.load()

    let navigationController = window?.rootViewController as? UINavigationController
    let travelLocationsViewController = navigationController?.topViewController as! TravelLocationsMapViewController
    travelLocationsViewController.dataController = dataController
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    // Save changes in the application's managed object context when the application transitions to the background.
    dataController.saveContext()
  }
}

