import Foundation
import UIKit
import CoreLocation
import CubicSpline
//import SwiftCubicSpline // better one?
@_spi(Experimental) import MapboxMaps

final class CustomRasterSourceExample: UIViewController, ExampleProtocol {
    
    private var mapView: MapView!
    private var cancelables: Set<AnyCancelable> = []
    internal var routeLineSource: GeoJSONSource!
    
    internal let sourceIdentifier = "route-source-identifier"
    
    private enum ID {
        static let customRasterSource = "custom-raster-source"
        static let rasterLayer = "customRaster"
    }
    let blackBackgroundStyleJSON = """
    {
      "version": 8,
      "name": "3D Terrain Satellite",
      "center": [
        0, 0
      ],
      "zoom": 13.955760822635057,
      "bearing": 60,
      "pitch": 60,
      "sources": {
      },
      "sprite": "mapbox://sprites/mapbox/bright-v8",
      "glyphs": "mapbox://fonts/mapbox-map-design/{fontstack}/{range}.pbf",
      "layers": [
        {
          "id": "background",
          "type": "background",
          "layout": {},
          "paint": {
            "background-color": "#000000"
          }
        }
      ],
      "visibility": "public",
      "protected": false,
      "draft": false
    }
    
    """
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = MapView(
            frame: view.bounds,
            mapInitOptions:
                    .init(cameraOptions: CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 4 ),
                          styleJSON: blackBackgroundStyleJSON
                         ))
        
        
        
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            print("onStyleLoaded")
            self?.setupExample()
            self?.finish()
        }
        .store(in: &cancelables)
        
        mapView.ornaments.scaleBarView.isHidden = true
    }
    
    
    private func setupExample() {
        do {
            addImageSource()
            addLine()
            mapView.gestures.onMapTap.observe { [weak self] gesture in
                guard let self = self else {
                    return
                }
                print("animate the poly")
                currentIndex = 0
                animatePolyline()
            }
            .store(in: &cancelables)
        } catch {
            print("[Example/CustomRasterSourceExample] Error:\(error)")
        }
    }
    
    func addImageSource() {
        let sourceId = "loveland-source"
        
        let yScale = lovelandImage.size.height / lovelandImage.size.width
        print("yScale = 0 -> \(yScale)")
        
        var imageSource = ImageSource(id: sourceId)
        imageSource.coordinates = [
            [0, yScale],
            [1, yScale],
            [1, 0],
            [0, 0]
        ]
        
        let imageLayer = RasterLayer(id: "radar-layer", source: sourceId)
        try! mapView.mapboxMap.addSource(imageSource)
        try! mapView.mapboxMap.addLayer(imageLayer)
        try! mapView.mapboxMap.updateImageSource(withId: sourceId, image: lovelandImage)
        
        // Add a tap gesture handler that will allow the animation to be stopped and started.
        mapView.gestures.onMapTap.observe { [weak self] context in
            guard let strongSelf = self else {
                return
            }
            let xPixel = strongSelf.lovelandImage.size.width * context.coordinate.longitude
            let yPixel = strongSelf.lovelandImage.size.width * context.coordinate.latitude
            let latLon = String(format: "%.4f, %.4f", xPixel, yPixel)
            print("Map Tapped \(latLon)")
        }.store(in: &cancelables)
        
        
        
        let southWest = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let northEast = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        let cameraOptions = mapView.mapboxMap.camera(for: [southWest, northEast], padding: .init(allEdges: 10), bearing: nil, pitch: nil)
        mapView.mapboxMap.setCamera(to: cameraOptions)
        
        var puckConfiguration = Puck2DConfiguration.makeDefault()
        puckConfiguration.pulsing = .default
        mapView.location.options.puckType = .puck2D(puckConfiguration)
        mapView.location.override(locationProvider: CustomLocationProvider())
    }
    
    let lowZoomWidth = 5
    let highZoomWidth = 20
    
    
    func addLine() {
        // Create a GeoJSON data source.
        routeLineSource = GeoJSONSource(id: sourceIdentifier)
        routeLineSource.data = .feature(Feature(geometry: LineString([TestData.allCoordinates[currentIndex]])))
        
        // Create a shadow layer
        var shadowLayer = LineLayer(id: "shadow-layer", source: sourceIdentifier)
        shadowLayer.lineColor = .constant(StyleColor(UIColor.systemGreen.withAlphaComponent(0.3))) // Softer color
        shadowLayer.lineWidth = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                14
                lowZoomWidth + 5 // Slightly wider than the main line
                18
                highZoomWidth + 5
            }
        )
        shadowLayer.lineCap = .constant(.round)
        shadowLayer.lineJoin = .constant(.round)
        
        // Add the shadow layer to the map.
        try! mapView.mapboxMap.addSource(routeLineSource)
        try! mapView.mapboxMap.addLayer(shadowLayer)
        
        // Create a main line layer
        var lineLayer = LineLayer(id: "line-layer", source: sourceIdentifier)
        lineLayer.lineColor = .constant(StyleColor(.systemGreen))
        lineLayer.lineOpacity = .constant(0.6)
        lineLayer.lineWidth = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                14
                lowZoomWidth
                18
                highZoomWidth
            }
        )
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)
        
        // Add the main lineLayer above the shadow layer.
        try! mapView.mapboxMap.addLayer(lineLayer, layerPosition: .above("shadow-layer"))
        
        // Define the source data and style layer for the airplane symbol.
        var airplaneSymbol = GeoJSONSource(id: "source-id")
        let point = Point(TestData.allCoordinates[0])
        airplaneSymbol.data = .feature(Feature(geometry: point))
        
        try? mapView.mapboxMap.addImage(UIImage(named: "dest-pin")!, id: "marker-icon-id")
        
        var symbolLayer = SymbolLayer(id: "layer-id", source: "source-id")
        symbolLayer.iconImage = .constant(.name("marker-icon-id"))
        symbolLayer.iconIgnorePlacement = .constant(true)
        symbolLayer.iconAllowOverlap = .constant(true)
        symbolLayer.iconOffset = .constant([0, -12])
        
        try! mapView.mapboxMap.addSource(airplaneSymbol)
        try! mapView.mapboxMap.addLayer(symbolLayer, layerPosition: nil)
    }
    
    func animatePolyline() {
        animationLock.lock()
        defer { animationLock.unlock() }
        
        animationTimer?.invalidate()
        
        var currentCoordinates = [CLLocationCoordinate2D]()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            animationLock.lock()
            defer { animationLock.unlock() }
            
            if self.currentIndex >= TestData.allCoordinates.count {
                timer.invalidate()
                return
            }
            
            
            currentCoordinates.append(TestData.allCoordinates[self.currentIndex])
            
            let updatedLine = Feature(geometry: LineString(currentCoordinates))
            self.routeLineSource.data = .feature(updatedLine)
            self.mapView.mapboxMap.updateGeoJSONSource(withId: self.sourceIdentifier,
                                                       geoJSON: .feature(updatedLine))
            
            
//            if self.currentIndex + 1 < TestData.allCoordinates.count {
                // move the airplane
                let coordinate = TestData.allCoordinates[self.currentIndex]
//                let nextCoordinate = TestData.allCoordinates[self.currentIndex + 1]
                var geoJSON = Feature(geometry: Point(coordinate))
//                geoJSON.properties = ["bearing": .number(coordinate.direction(to: nextCoordinate))]
                self.mapView.mapboxMap.updateGeoJSONSource(withId: "source-id",
                                                                      geoJSON: .feature(geoJSON))
//            }
            
            self.currentIndex += 1
        }
    }
    
    private let lovelandImage: UIImage = UIImage(named: "Loveland")!
    private let animationLock = NSLock()
    private var currentIndex = 0
    private var animationTimer: Timer? = nil
}

// Custom Location Provider
class CustomLocationProvider: NSObject, LocationProvider {
    func addLocationObserver(for observer: LocationObserver) { }
    
    func removeLocationObserver(for observer: LocationObserver) { }
    
    func getLastObservedLocation() -> Location? {
        Location(clLocation: CLLocation(latitude: 0.5, longitude: 0.5))
    }
}
