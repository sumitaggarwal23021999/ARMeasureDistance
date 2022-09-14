

import UIKit
import SceneKit
import ARKit

extension SCNGeometry {
    class func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]

        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)

        return SCNGeometry(sources: [source], elements: [element])
    }
}

extension SCNVector3 {
    static func distanceFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> Float {
        let x0 = vector1.x
        let x1 = vector2.x
        let y0 = vector1.y
        let y1 = vector2.y
        let z0 = vector1.z
        let z1 = vector2.z

        return sqrtf(powf(x1-x0, 2) + powf(y1-y0, 2) + powf(z1-z0, 2))
    }
}

extension Float {
    func metersToInches() -> Float {
        return self * 39.3701
    }
}

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    var grids = [Grid]()
    var numberOfTaps = 0
    var startPoint: SCNVector3!
    var endPoint: SCNVector3!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        sceneView.automaticallyUpdatesLighting = true
        let scene = SCNScene()
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(gestureRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func tapped(gesture: UITapGestureRecognizer) {
        // Get 2D position of touch event on screen
        numberOfTaps += 1
        let touchPosition = gesture.location(in: sceneView)

        // Translate those 2D points to 3D points using hitTest (existing plane)
        let hitTestResults = sceneView.hitTest(touchPosition, types: .existingPlane)

        guard let hitTest = hitTestResults.first else {
            return
        }
        
        // If first tap, add red marker. If second tap, add green marker and reset to 0
        if numberOfTaps == 1 {
            startPoint = SCNVector3(hitTest.worldTransform.columns.3.x, hitTest.worldTransform.columns.3.y, hitTest.worldTransform.columns.3.z)
            addRedMarker(hitTestResult: hitTest)
        }
        else {
            // After 2nd tap, reset taps to 0
            numberOfTaps = 0
            endPoint = SCNVector3(hitTest.worldTransform.columns.3.x, hitTest.worldTransform.columns.3.y, hitTest.worldTransform.columns.3.z)
            addGreenMarker(hitTestResult: hitTest)
            addLineBetween(start: startPoint, end: endPoint)
            addDistanceText(distance: SCNVector3.distanceFrom(vector: startPoint, toVector: endPoint), at: endPoint)
        }
        
        
    }
    
    func addLineBetween(start: SCNVector3, end: SCNVector3) {
        let lineGeometry = SCNGeometry.lineFrom(vector: start, toVector: end)
        let lineNode = SCNNode(geometry: lineGeometry)

        sceneView.scene.rootNode.addChildNode(lineNode)
    }
    
    func addDistanceText(distance: Float, at point: SCNVector3) {
        let textGeometry = SCNText(string: String(format: "%.1f\"", distance.metersToInches()), extrusionDepth: 1)
        textGeometry.font = UIFont.systemFont(ofSize: 10)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.black

        let textNode = SCNNode(geometry: textGeometry)
        textNode.position = SCNVector3Make(point.x, point.y, point.z);
        textNode.scale = SCNVector3Make(0.005, 0.005, 0.005)

        sceneView.scene.rootNode.addChildNode(textNode)
    }
    
    func addRedMarker(hitTestResult: ARHitTestResult) {
        addMarker(hitTestResult: hitTestResult, color: .red)
    }

    func addGreenMarker(hitTestResult: ARHitTestResult) {
        addMarker(hitTestResult: hitTestResult, color: .green)
    }

    func addMarker(hitTestResult: ARHitTestResult, color: UIColor) {
        let geometry = SCNSphere(radius: 0.01)
        geometry.firstMaterial?.diffuse.contents = color

        let markerNode = SCNNode(geometry: geometry)
        markerNode.position = SCNVector3(hitTestResult.worldTransform.columns.3.x, hitTestResult.worldTransform.columns.3.y, hitTestResult.worldTransform.columns.3.z)

        sceneView.scene.rootNode.addChildNode(markerNode)
    }
    
}

extension ViewController: ARSCNViewDelegate {
//    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//        if let planeAnchor = anchor as? ARPlaneAnchor {
//            debugPrint("Plane detected")
//            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
//            let planeNode = SCNNode()
//            planeNode.position = SCNVector3(x: planeAnchor.center.x, y: 0, z: planeAnchor.center.z)
//            planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
//            let gridMaterial = SCNMaterial()
//            gridMaterial.diffuse.contents = UIImage(named: "art.scnassets/grid.png")
//            plane.materials = [gridMaterial]
//            planeNode.geometry = plane
//            node.addChildNode(planeNode)
//        } else {
//            return
//        }
//    }
    
    // 1.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let grid = Grid(anchor: anchor as! ARPlaneAnchor)
        self.grids.append(grid)
        node.addChildNode(grid)
    }
    
    // 2.
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        let grid = self.grids.filter { grid in
            return grid.anchor.identifier == anchor.identifier
        }.first

        guard let foundGrid = grid else {
            return
        }

        foundGrid.update(anchor: anchor as! ARPlaneAnchor)
    }
}
