#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float depositPercent;  // 0.0 = empty, 1.0 = full
    float time;            // used for the subtle wave offset
};

// Vertex shader: Passes through positions and texture coordinates.
vertex VertexOut vertexShader(const device float *vertices [[buffer(0)]],
                              unsigned int vid [[vertex_id]]) {
    VertexOut out;
    float4 pos = float4(vertices[vid*4], vertices[vid*4 + 1], 0.0, 1.0);
    out.position = pos;
    out.texCoord = float2(vertices[vid*4 + 2], vertices[vid*4 + 3]);
    return out;
}

// Fragment shader: Renders a still water fill with a constant color (#75F73E) inside a round container.
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(0)]])
{
    // UV coordinates range from 0 to 1.
    float2 uv = in.texCoord;
    
    // Define a round container (a circle) centered at (0.5, 0.5) with a radius of 0.45.
    float2 containerCenter = float2(0.5, 0.5);
    float containerRadius = 0.45;
    bool insideContainer = distance(uv, containerCenter) <= containerRadius;
    
    // Map depositPercent (0 to 1) to the container's vertical fill level.
    float containerBottom = containerCenter.y - containerRadius;
    float containerHeight = containerRadius * 2.0;
    float baseWaterLevel = containerBottom + uniforms.depositPercent * containerHeight;
    
    // Add a subtle wave offset to the water level.
    float wave = 0.02 * sin(uv.x * 20.0 + uniforms.time * 3.0);
    float waterLine = baseWaterLevel + wave;
    
    // Render water only if within the container and below the water line.
    if (insideContainer && uv.y < waterLine) {
        // Constant water color: #75F73E (R: 117/255, G: 247/255, B: 62/255)
        return float4(117.0/255.0, 247.0/255.0, 62.0/255.0, 1.0);
    } else {
        // Outside the container or above water: transparent.
        return float4(0.0, 0.0, 0.0, 0.0);
    }
}
