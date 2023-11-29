import UIKit
@_spi(Experimental) import MapboxMaps

final class CustomRasterSourceExample: UIViewController, ExampleProtocol {
    
    private var mapView: MapView!
    private var cancelables: Set<AnyCancelable> = []
    private var timer: Timer?
    
    private enum ID {
        static let customRasterSource = "custom-raster-source"
        static let rasterLayer = "customRaster"
    }
    
    deinit {
        timer?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = MapView(
            frame: view.bounds,
            mapInitOptions:
                    .init(cameraOptions: CameraOptions(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 4 ),
                          styleURI: StyleURI(rawValue: "mapbox://styles/mapbox-map-design/ckhqrf2tz0dt119ny6azh975y")
                         ))
        
        
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            self?.setupExample()
            self?.finish()
        }
        .store(in: &cancelables)
        
        mapView.ornaments.scaleBarView.isHidden = true
        try! mapView.mapboxMap.allLayerIdentifiers.forEach{ id in
            try mapView.mapboxMap.removeLayer(withId: id.id)
        }
    }
    
    
    private func setupExample() {
        do {
            try mapView.mapboxMap.allLayerIdentifiers.forEach{ id in
                try mapView.mapboxMap.removeLayer(withId: id.id)
            }
            
            addImageSource()
            addTerrain()
            
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
    }
    
    func addTerrain() {
        var demSource = RasterDemSource(id: "mapbox-dem")
        demSource.url = "mapbox://mapbox.mapbox-terrain-dem-v1"
        // Setting the `tileSize` to 514 provides better performance and adds padding around the outside
        // of the tiles.
        demSource.tileSize = 514
        demSource.maxzoom = 14.0
        try! mapView.mapboxMap.addSource(demSource)

        var terrain = Terrain(sourceId: "mapbox-dem")
        terrain.exaggeration = .constant(1.5)

        try! mapView.mapboxMap.setTerrain(terrain)
    }
    
    private let lovelandImage: UIImage = UIImage(named: "Loveland")!
}
