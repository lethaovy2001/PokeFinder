//
//  ViewController.swift
//  PokeFinder
//
//  Created by Vy Le on 3/23/18.
//  Copyright © 2018 Vy Le. All rights reserved.
//

import UIKit
// 1. Import MapKit & FirebaseDatabase
import MapKit
import FirebaseDatabase


// 2. Implement MKMapViewDelegate, CLLocationManagerDelegate
class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    // 3. Create locationManager
    let locationManager = CLLocationManager()
    var mapHasCenteredOnce = false
    
    var geoFire: GeoFire!
    var geoFireRef: DatabaseReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 4.1 Set delegate
        mapView.delegate = self
        
        // 4.2 Set trackingMode (follow where the user goes)
        mapView.userTrackingMode = MKUserTrackingMode.follow
        
        geoFireRef = Database.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus()
    }
    
    // 5. Create a function to check the authorization status to use User Location
    func locationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            // Get user location on the Map
            mapView.showsUserLocation = true
        } else {
           //Request permission if not authorization location yet
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // 6. Update the user location or not based on their decision in #5
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
    
    // 7. Center the map on present location
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 2000)
        
        // set position and zoom level on the screen
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    // 8. When GPS on the phone update, center that map
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        if let loc = userLocation.location {
            
            // Only center once when the app first load
            if !mapHasCenteredOnce {
                centerMapOnLocation(location: loc)
                mapHasCenteredOnce = true
            }
        }
    }
    
    // 9. Configuring annotation before show in the map
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        
        let annoIdentifier = "Pokemon"
        var annotationView: MKAnnotationView?
        
        // 9.1  Customize User location with an annotation
        if annotation.isKind(of: MKUserLocation.self) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
            
            // 9.2 Reuse annotation if needed
            // dequeueReusableAnnotationView is similar to tableView
        } else if let deqAnno = mapView.dequeueReusableAnnotationView(withIdentifier: annoIdentifier) {
            annotationView = deqAnno
            annotationView?.annotation = annotation
            
            // 9.3 Create a default annotation
        } else {
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: annoIdentifier)
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = av
        }
        
        // 9.4 Show little pop up when clicked on the annotation (Pokemon)
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation {
            // ***Note: remember to set the title for the anno in the PokeAnnotation, otherwise it will crash***
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: "\(anno.pokemonNumber)")
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
        }
        
        return annotationView
        
    }
    
    // =========== GeoFire ====================
    
    
    // 10. Create Annotation
    func createSighting(forLocation location: CLLocation, withPokemon pokeId: Int) {
        
        // Add location data into Firebase hosting
        geoFire.setLocation(location, forKey: "\(pokeId)")
    }
    
    // 11. Show Sightings on the screen (Display Pokemon on the screen)
    func showSightingsOnMap(location: CLLocation) {
        
        // From GeoFire Documentary
        let circleQuery = geoFire.query(at: location, withRadius: 2.5)  // 2.5km
        
        // keyEnter: Find a key for a location -> Show it
        _ = circleQuery.observe(.keyEntered, with: { (key: String!, location: CLLocation!) in
            
            
            if let key = key, let location = location {
                
                // Show annotation of what was saved  from the setLocation in #10
                let anno = PokeAnnotation(coordinate: location.coordinate, pokemonNumber: Int(key)!)
                // addAnnotation will call #9 to configure the annotation
                self.mapView.addAnnotation(anno)
            }
        })
        
    }
    
    //==============================================
    
    // 12. Show pokemon whenever the user change the region
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        showSightingsOnMap(location: loc)
    }
    
    // 13. Tap the pop up on the pokemon, and tap the map -> Open Apple Map to show the location to that Pokemon
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let anno = view.annotation as? PokeAnnotation {
            // Configuring the Apple Map before loaded
            
            var place: MKPlacemark!
            if #available(iOS 10.0, *) {
                place = MKPlacemark(coordinate: anno.coordinate)
            } else {
                place = MKPlacemark(coordinate: anno.coordinate, addressDictionary: nil)
            }
            
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon Sighting"
            
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            
            
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey:  NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
        
    }
    
    // Display Pokemon right in the middle of the map
    @IBAction func spotRandomPokemon(_ sender: AnyObject) {
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)

        let rand = arc4random_uniform(151) + 1
        createSighting(forLocation: loc, withPokemon: Int(rand))
    }
    
}

