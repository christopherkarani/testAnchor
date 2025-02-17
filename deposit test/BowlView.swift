import GameplayKit
import SwiftUI

// MARK: - GameplayKit Component for Water Waves
class WaterWaveComponent: GKComponent {
    weak var waterNode: SKSpriteNode?
    private var time: TimeInterval = 0

    init(waterNode: SKSpriteNode) {
        self.waterNode = waterNode
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update(deltaTime seconds: TimeInterval) {
        time += seconds
        // Apply a sine-wave offset to the water's horizontal position.
        let waveOffset = CGFloat(sin(time * 2 * Double.pi / 3)) * 10.0
        waterNode?.position.x = waveOffset
    }
}

// MARK: - SKScene Representing the Bowl
class BowlScene: SKScene {
    /// A deposit percentage between 0 (empty) and 1 (full).
    var depositPercent: CGFloat = 0.5 {
        didSet {
            updateWaterLevel()
        }
    }

    private var waterNode: SKSpriteNode!
    private var cropNode: SKCropNode!
    private var waterWaveComponentSystem = GKComponentSystem(componentClass: WaterWaveComponent.self)

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        // Create a bowl mask as an oval shape.
        let bowlMask = SKShapeNode(path: bowlPath())
        bowlMask.fillColor = .white
        bowlMask.strokeColor = .clear

        // Set up a crop node with the bowl shape as its mask.
        cropNode = SKCropNode()
        cropNode.maskNode = bowlMask
        cropNode.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(cropNode)

        // Create the water node. Its full height matches the bowl mask's height.
        let bowlFrame = bowlMask.frame
        waterNode = SKSpriteNode(color: UIColor.systemGreen, size: CGSize(width: bowlFrame.width * 1.5, height: bowlFrame.height))
        waterNode.anchorPoint = CGPoint(x: 0.5, y: 0) // Bottom anchor
        // Position so that the bottom of the water aligns with the bottom of the bowl.
        waterNode.position = CGPoint(x: 0, y: -bowlFrame.height/2)
        // Set initial fill level via yScale.
        waterNode.yScale = depositPercent
        cropNode.addChild(waterNode)

        // Add a GameplayKit component to simulate a subtle wave effect.
        let waterWaveComponent = WaterWaveComponent(waterNode: waterNode)
        waterWaveComponentSystem.addComponent(waterWaveComponent)

        // Also add an SKAction wave to further animate horizontal movement.
        let moveLeft = SKAction.moveBy(x: -20, y: 0, duration: 1.5)
        let moveRight = SKAction.moveBy(x: 20, y: 0, duration: 1.5)
        let waveAction = SKAction.repeatForever(SKAction.sequence([moveLeft, moveRight]))
        waterNode.run(waveAction)
    }

    override func update(_ currentTime: TimeInterval) {
        // Update the GameplayKit wave component.
        waterWaveComponentSystem.update(deltaTime: 1.0/60.0)
    }

    /// Animates the water level by scaling the water node's yScale.
    func updateWaterLevel() {
        let targetScaleY = depositPercent
        let scaleAction = SKAction.scaleY(to: targetScaleY, duration: 0.5)
        waterNode.run(scaleAction)
    }

    /// Returns an oval CGPath representing the bowl shape.
    func bowlPath() -> CGPath {
        let width = size.width * 0.8
        let height = size.height * 0.5
        let bowlRect = CGRect(x: -width/2, y: -height/2, width: width, height: height)
        return UIBezierPath(ovalIn: bowlRect).cgPath
    }

    /// Update the deposit percentage (clamped between 0 and 1).
    func setDepositPercent(_ percent: CGFloat) {
        depositPercent = max(0, min(1, percent))
    }
}

// MARK: - SwiftUI Wrapper for the BowlScene
struct BowlView: UIViewRepresentable {
    @Binding var depositPercent: CGFloat

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        let sceneSize = CGSize(width: 300, height: 300)
        let scene = BowlScene(size: sceneSize)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
        context.coordinator.scene = scene
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.scene?.setDepositPercent(depositPercent)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var scene: BowlScene?
    }
}

#Preview {
    BowlView(depositPercent: .constant(0.5))
        .frame(width: 300, height: 300)
}
