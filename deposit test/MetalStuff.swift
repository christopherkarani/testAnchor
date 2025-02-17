///
//  MetalStuff.swift
//  deposit test
//
//  Created by Chris Karani on 15/02/2025.
//
import CoreMotion
import simd

class MotionManager {
    static let shared = MotionManager()
    
    private let manager = CMMotionManager()
    // The tilt is updated from the device's roll and pitch.
    // You can choose which values to use; here we use roll for x and pitch for y.
    var tilt: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    private init() {
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            // Use the main queue or a background queue as needed.
            manager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion else { return }
                // Normalize roll and pitch to a reasonable range. You may need to tweak these values.
                let roll = Float(motion.attitude.roll)  // left/right tilt
                let pitch = Float(motion.attitude.pitch) // forward/back tilt
                self.tilt = SIMD2<Float>(roll, pitch)
            }
        }
    }
}

//
//  MetalStuff.swift
//  deposit test
//
//  Created by Chris Karani on 15/02/2025.
//

import MetalKit
import simd

// Structure matching our shader uniform (16 bytes total)
struct Uniforms {
    var depositPercent: Float   // 0.0 (empty) to 1.0 (full)  (4 bytes)
    var time: Float             // Animation time                (4 bytes)
    var tilt: SIMD2<Float>      // Device tilt (x, y)            (8 bytes)
}

class MetalWaterRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    
    // Full-screen quad vertex data: position (x,y) and texture coordinates (u,v)
    var vertexBuffer: MTLBuffer!
    
    // Our uniforms that the shader will use.
    var uniforms = Uniforms(depositPercent: 0.5, time: 0, tilt: SIMD2<Float>(0, 0))
    var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    init(mtkView: MTKView) {
        super.init()
        self.device = mtkView.device
        commandQueue = device.makeCommandQueue()
        
        // Load the default library (make sure "Shaders.metal" is part of your target)
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Water Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Full-screen quad (two triangles)
        // Each vertex: [position.x, position.y, texCoord.x, texCoord.y]
        let vertices: [Float] = [
            -1,  1,  0, 1,
            -1, -1,  0, 0,
             1, -1,  1, 0,
            
            -1,  1,  0, 1,
             1, -1,  1, 0,
             1,  1,  1, 1
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Float>.size,
                                         options: [])
    }
    
    func updateUniforms() {
        let currentTime = Float(CFAbsoluteTimeGetCurrent() - startTime)
        uniforms.time = currentTime
        // Update tilt from the MotionManager
        uniforms.tilt = MotionManager.shared.tilt
        // depositPercent is updated externally via the SwiftUI binding.
    }
    
    func draw(in view: MTKView) {
        updateUniforms()
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // Use MemoryLayout<Uniforms>.stride to pass all 16 bytes.
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Resize handling if necessary.
    }
}

import SwiftUI
import MetalKit

struct MetalWaterView: UIViewRepresentable {
    @Binding var depositPercent: Float  // 0.0 to 1.0
    
    class Coordinator: NSObject {
        var renderer: MetalWaterRenderer?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1) // White background
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        let renderer = MetalWaterRenderer(mtkView: mtkView)
        context.coordinator.renderer = renderer
        mtkView.delegate = renderer
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update the uniform's depositPercent so the shader sees the current fill level.
        context.coordinator.renderer?.uniforms.depositPercent = depositPercent
    }
}

import SwiftUI

struct MetalContent: View {
    @State private var depositPercent: Float = 0.5
    
    var body: some View {
        VStack {
            MetalWaterView(depositPercent: $depositPercent)
                .frame(width: 300, height: 300)
                .cornerRadius(12)
                .shadow(radius: 5)
            
            Slider(value: $depositPercent, in: 0...1)
                .padding()
            
            Text("Deposit: \(Int(depositPercent * 100))%")
                .font(.system(.title, design: .rounded))
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MetalContent()
    }
}
