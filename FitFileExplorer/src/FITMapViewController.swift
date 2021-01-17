//
//  FITMapViewController.swift
//  GarminConnect
//
//  Created by Brice Rosenzweig on 19/11/2016.
//  Copyright © 2016 Brice Rosenzweig. All rights reserved.
//

import Cocoa
import MapKit
import FitFileParser

class FITMapViewController: NSViewController,MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView?
    
    var selectionContext : FITSelectionContext?
    
    var gradientPath : GCMapGradientPathOverlay?
    
    var fitFile : FitFile? {
        return self.selectionContext?.fitFile
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.mapView?.delegate = self
        if let selectionContext = self.selectionContext{
            self.updateWith(selectionContext: selectionContext)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let mapOverlay as GCMapGradientPathOverlay:
            return GCMapGradientPathOverlayView(overlay: mapOverlay)
        default:
            return MKOverlayRenderer()
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let mapAnnotation as GCMapAnnotation:
            let rv = MKPinAnnotationView(annotation: mapAnnotation, reuseIdentifier: "GCMapAnnotation")
            rv.pinTintColor = MKPinAnnotationView.greenPinColor()
            return rv
        default:
            return MKAnnotationView()
        }
    }
    // Called from FITSPlitViewController.detailSelectionChanged upon notification of table change
    func updateWith(selectionContext:FITSelectionContext){
        self.selectionContext = selectionContext
        
        if self.mapView != nil {
            self.mapView?.delegate = self
            
            if  let locationField = selectionContext.selectedLocationField{
                let interp = selectionContext.interp
                let messageType = selectionContext.messageType
                if let coords = interp.coordinatePoints(messageType: messageType, field: locationField){
                    self.mapView!.removeOverlays(self.mapView!.overlays)
                    
                    var holders : [GCMapRouteLogicPointHolder] = []
                    
                    for coord in coords {
                        if let holder = GCMapRouteLogicPointHolder(coord, color: NSColor.blue, start: false){
                            holders.append(holder)
                        }
                    }
                    let overlay = GCMapGradientPathOverlay()
                    overlay.points = holders
                    overlay.calculateBoundingMapRect()
                    overlay.gradientColors = GCViewGradientColors(single: NSColor.blue)
                    self.mapView?.addOverlay(overlay)
                    
                    self.mapView?.setVisibleMapRect(overlay.boundingMapRect, animated: true)
                    
                    if let message = selectionContext.message,
                        let co = message.coordinate(field: locationField){
                        self.mapView!.removeAnnotations(self.mapView!.annotations)
                        self.mapView!.addAnnotation(GCMapAnnotation(coord: co, title: "Current", andType: gcMapAnnotation.lap))
                        
                    }
                }
            }
        }
    }
}
