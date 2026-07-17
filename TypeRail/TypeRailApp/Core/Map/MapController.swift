//
//  MapController.swift
//  TypeRailApp
//

import MapKit
import SwiftUI

/// SwiftUI wrapper for MKMapView to handle polyline overlay + custom train annotation.
struct MapController: UIViewRepresentable {
    let route: MRTRoute
    let trainCoordinate: CLLocationCoordinate2D
    let cameraHeading: CLLocationDirection
    let cameraDistance: CLLocationDistance
    let cameraPitch: CGFloat

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = false
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.isPitchEnabled = true
        map.isRotateEnabled = true

        // Add route polyline
        let polyline = MKPolyline(coordinates: route.polylinePoints, count: route.polylinePoints.count)
        map.addOverlay(polyline)

        // Add station annotations
        let annotations = route.stations.map { station -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = station.coordinate
            annotation.title = station.name
            return annotation
        }
        map.addAnnotations(annotations)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Update camera position
        let camera = MKMapCamera(
            lookingAtCenter: trainCoordinate,
            fromDistance: cameraDistance,
            pitch: cameraPitch,
            heading: cameraHeading
        )
        map.setCamera(camera, animated: true)

        // Update train annotation
        context.coordinator.updateTrainAnnotation(on: map, at: trainCoordinate)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var trainAnnotation: MKPointAnnotation?

        func updateTrainAnnotation(on map: MKMapView, at coordinate: CLLocationCoordinate2D) {
            if let existing = trainAnnotation {
                existing.coordinate = coordinate
            } else {
                let annotation = MKPointAnnotation()
                annotation.title = "🚃"
                annotation.coordinate = coordinate
                map.addAnnotation(annotation)
                trainAnnotation = annotation
            }
        }

        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            return renderer
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            if annotation === trainAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "train")
                view.canShowCallout = false
                view.image = UIImage(systemName: "tram.fill")
                view.frame.size = CGSize(width: 24, height: 24)
                return view
            }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "station")
            view.canShowCallout = true
            return view
        }
    }
}
