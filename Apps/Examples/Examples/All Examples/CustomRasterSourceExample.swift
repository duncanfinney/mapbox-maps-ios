import UIKit
import CoreLocation
@_spi(Experimental) import MapboxMaps

final class CustomRasterSourceExample: UIViewController, ExampleProtocol {
    
    private var mapView: MapView!
    private var cancelables: Set<AnyCancelable> = []
    
    private enum ID {
        static let customRasterSource = "custom-raster-source"
        static let rasterLayer = "customRaster"
    }
    let blackBackgroundStyleJSON = """
    {
      "version": 8,
      "name": "3D Terrain Satellite",
      "metadata": {
        "mapbox:type": "default",
        "mapbox:origin": "satellite-streets-v11",
        "mapbox:sdk-support": {
          "android": "9.3.0",
          "ios": "5.10.0",
          "js": "1.10.0"
        },
        "mapbox:autocomposite": true,
        "mapbox:groups": {
          
        },
        "mapbox:trackposition": false
      },
      "center": [
        0, 0
      ],
      "zoom": 13.955760822635057,
      "bearing": 60,
      "pitch": 60,
      "sources": {
      },
      "sprite": "mapbox://sprites/mapbox-map-design/ckhqrf2tz0dt119ny6azh975y/4snix0v8fnkivnb584t41dzcl",
      "glyphs": "mapbox://fonts/mapbox-map-design/{fontstack}/{range}.pbf",
      "layers": [
        {
          "id": "background",
          "type": "background",
          "layout": {},
          "paint": {
            "background-color": "#FFC0CB"
          }
        }
      ],
      "created": "2020-11-20T21:12:35.724Z",
      "modified": "2020-11-20T21:18:04.744Z",
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
//                          styleURI: StyleURI(rawValue: "mapbox://styles/mapbox-map-design/ckhqrf2tz0dt119ny6azh975y")
                          styleJSON: blackBackgroundStyleJSON
                         ))
        
        
        
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
//        setupExample()
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            print("onStyleLoaded")
            self?.setupExample()
            self?.finish()
        }
        .store(in: &cancelables)
        
        mapView.ornaments.scaleBarView.isHidden = true
//        try! mapView.mapboxMap.allLayerIdentifiers.forEach{ id in
//            try mapView.mapboxMap.removeLayer(withId: id.id)
//        }
    }
    
    
    private func setupExample() {
        do {
//            try mapView.mapboxMap.allLayerIdentifiers.forEach{ id in
//                try mapView.mapboxMap.removeLayer(withId: id.id)
//            }
            
            addImageSource()
//            addTerrain()
            
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
    
//    func addTerrain() {
//        var demSource = RasterDemSource(id: "mapbox-dem")
//        demSource.url = "mapbox://mapbox.mapbox-terrain-dem-v1"
//        // Setting the `tileSize` to 514 provides better performance and adds padding around the outside
//        // of the tiles.
//        demSource.tileSize = 514
//        demSource.maxzoom = 14.0
//        try! mapView.mapboxMap.addSource(demSource)
//        
//        var terrain = Terrain(sourceId: "mapbox-dem")
//        terrain.exaggeration = .constant(1.5)
//        
//        try! mapView.mapboxMap.setTerrain(terrain)
//    }
    
    private let lovelandImage: UIImage = UIImage(named: "Loveland")!
}

// Custom Location Provider
class CustomLocationProvider: NSObject, LocationProvider {
    func addLocationObserver(for observer: LocationObserver) { }
    
    func removeLocationObserver(for observer: LocationObserver) { }
    
    func getLastObservedLocation() -> Location? {
        Location(clLocation: CLLocation(latitude: 0.5, longitude: 0.5))
    }
}
