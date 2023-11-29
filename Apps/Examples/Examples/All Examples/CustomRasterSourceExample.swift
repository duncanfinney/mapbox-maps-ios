import UIKit
import CoreLocation
@_spi(Experimental) import MapboxMaps

final class CustomRasterSourceExample: UIViewController, ExampleProtocol {
    
    private var mapView: MapView!
    private var cancelables: Set<AnyCancelable> = []
    internal var routeLineSource: GeoJSONSource!
    let allCoordinates = [
        LocationCoordinate2D(latitude: 876, longitude: 950),
        LocationCoordinate2D(latitude: 850, longitude: 912),
        LocationCoordinate2D(latitude: 820, longitude: 894),
        LocationCoordinate2D(latitude: 767, longitude: 904),
        LocationCoordinate2D(latitude: 716, longitude: 948),
        LocationCoordinate2D(latitude: 637, longitude: 995),
        LocationCoordinate2D(latitude: 596, longitude: 1046),
        LocationCoordinate2D(latitude: 538, longitude: 1114),
        LocationCoordinate2D(latitude: 479, longitude: 1143),
        LocationCoordinate2D(latitude: 458, longitude: 1146),
        LocationCoordinate2D(latitude: 468, longitude: 1199),
        LocationCoordinate2D(latitude: 470, longitude: 1263),
        LocationCoordinate2D(latitude: 481, longitude: 1344),
        LocationCoordinate2D(latitude: 482, longitude: 1362),
        LocationCoordinate2D(latitude: 455, longitude: 1417),
    ].map { loc in
        let transformedX = loc.longitude / 3184
        let transformedY = loc.latitude / 3184
        return LocationCoordinate2D(latitude: transformedY, longitude: transformedX)
    }
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
    
    func addLine() {

        // Create a GeoJSON data source.
        routeLineSource = GeoJSONSource(id: sourceIdentifier)
        routeLineSource.data = .feature(Feature(geometry: LineString(allCoordinates)))

        // Create a line layer
        var lineLayer = LineLayer(id: "line-layer", source: sourceIdentifier)
        lineLayer.lineColor = .constant(StyleColor(.red))

        let lowZoomWidth = 5
        let highZoomWidth = 20

        // Use an expression to define the line width at different zoom extents
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

        // Add the lineLayer to the map.
        try! mapView.mapboxMap.addSource(routeLineSource)
        try! mapView.mapboxMap.addLayer(lineLayer)
    }
    
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
