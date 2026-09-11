import Ayagami
import CoreVideo
import Metal
import MetalKit

private let shaderSource = """
#include <metal_stdlib>

using namespace metal;

constant bool live2DUseMask [[function_constant(0)]];

struct Live2DVertexUniforms {
    float2 scale;
    float2 offset;
};

struct Live2DFragmentUniforms {
    float3 multiplyColor;
    float opacity;
    float3 screenColor;
    uint invertMask;
};

struct Live2DVaryings {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex Live2DVaryings live2DVertex(uint vertexId [[vertex_id]],
                                   const device float2 *positions [[buffer(0)]],
                                   const device float2 *textureCoordinates [[buffer(1)]],
                                   constant Live2DVertexUniforms &uniforms [[buffer(2)]])
{
    Live2DVaryings out;
    out.position = float4(positions[vertexId] * uniforms.scale + uniforms.offset, 0, 1);
    out.textureCoordinate = textureCoordinates[vertexId];
    return out;
}

constexpr sampler live2DSampler(filter::linear, mip_filter::linear, address::clamp_to_edge);

fragment float4 live2DFragment(Live2DVaryings in [[stage_in]],
                               texture2d<float> texture [[texture(0)]],
                               texture2d<float> mask [[texture(1), function_constant(live2DUseMask)]],
                               constant Live2DFragmentUniforms &uniforms [[buffer(0)]])
{
    float4 color = texture.sample(live2DSampler, in.textureCoordinate);
    color.rgb *= color.a;
    color.rgb *= uniforms.multiplyColor;
    color.rgb = color.a - (color.a - color.rgb) * (1 - uniforms.screenColor);
    float maskValue = 1;
    if (live2DUseMask) {
        float2 maskCoordinate = in.position.xy / float2(mask.get_width(), mask.get_height());
        maskValue = mask.sample(live2DSampler, maskCoordinate).r;
        if (uniforms.invertMask != 0) {
            maskValue = 1 - maskValue;
        }
    }
    return saturate(color) * uniforms.opacity * maskValue;
}

fragment float4 live2DMaskFragment(Live2DVaryings in [[stage_in]],
                                   texture2d<float> texture [[texture(0)]])
{
    return float4(texture.sample(live2DSampler, in.textureCoordinate).a);
}
"""

private let library: MTLLibrary? = {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return nil
    }
    do {
        return try device.makeLibrary(source: shaderSource, options: nil)
    } catch {
        logger.info("v-tuber: Failed to compile shaders: \(error)")
        return nil
    }
}()

private struct Live2DVertexUniforms {
    var scale: SIMD2<Float>
    var offset: SIMD2<Float>
}

private struct Live2DFragmentUniforms {
    var multiplyColor: SIMD3<Float>
    var opacity: Float
    var screenColor: SIMD3<Float>
    var invertMask: UInt32
}

private struct Live2DPipelineKey: Hashable {
    let blendMode: AyagamiBlendMode
    let masked: Bool
}

private struct Live2DArtMesh {
    let info: AyagamiArtMeshInfo
    let clipSet: Int?
}

private struct Live2DClipSet {
    let targets: [UInt32]
    var texture: MTLTexture?
}

final class Live2DRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textures: [MTLTexture]
    private let indexBuffer: MTLBuffer
    private let texcoordBuffer: MTLBuffer
    private let vertexBuffer: MTLBuffer
    private let artMeshes: [Live2DArtMesh]
    private var clipSets: [Live2DClipSet]
    private var pipelines: [Live2DPipelineKey: MTLRenderPipelineState] = [:]
    private let maskPipeline: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private var vertexUniforms: Live2DVertexUniforms

    init?(model: AyagamiModel) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library
        else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        let textureLoader = MTKTextureLoader(device: device)
        var textures: [MTLTexture] = []
        for texturePath in model.texturePaths {
            do {
                try textures.append(textureLoader.newTexture(URL: texturePath, options: [
                    .SRGB: false,
                    .generateMipmaps: true,
                ]))
            } catch {
                logger.info("v-tuber: Failed to load texture \(texturePath.lastPathComponent): \(error)")
                return nil
            }
        }
        self.textures = textures
        let indices = model.indices
        let texcoords = model.texcoords
        guard let indexBuffer = device.makeBuffer(bytes: indices.baseAddress!,
                                                  length: indices.count * 2,
                                                  options: .storageModeShared),
            let texcoordBuffer = device.makeBuffer(bytes: texcoords.baseAddress!,
                                                   length: texcoords.count * 4,
                                                   options: .storageModeShared),
            let vertexBuffer = device.makeBuffer(length: texcoords.count * 4, options: .storageModeShared)
        else {
            return nil
        }
        self.indexBuffer = indexBuffer
        self.texcoordBuffer = texcoordBuffer
        self.vertexBuffer = vertexBuffer
        var artMeshes: [Live2DArtMesh] = []
        var clipSets: [Live2DClipSet] = []
        var clipSetIndexes: [[UInt32]: Int] = [:]
        for uid in 0 ..< UInt32(model.artMeshCount) {
            guard let info = model.artMeshInfo(uid) else {
                return nil
            }
            var clipSet: Int?
            if !info.clips.isEmpty {
                if let index = clipSetIndexes[info.clips] {
                    clipSet = index
                } else {
                    clipSet = clipSets.count
                    clipSetIndexes[info.clips] = clipSets.count
                    clipSets.append(Live2DClipSet(targets: info.clips, texture: nil))
                }
            }
            artMeshes.append(Live2DArtMesh(info: info, clipSet: clipSet))
        }
        self.artMeshes = artMeshes
        self.clipSets = clipSets
        let flip = SIMD2<Float>(1, -1)
        let scale = 2 * model.canvas.scale / model.canvas.dimensions * flip
        let offset = (2 * model.canvas.center / model.canvas.dimensions - 1) * flip
        vertexUniforms = Live2DVertexUniforms(scale: scale, offset: offset)
        do {
            maskPipeline = try Self.makeMaskPipeline(device: device, library: library)
            for blendMode in [AyagamiBlendMode.normal, .add, .multiply] {
                for masked in [false, true] {
                    pipelines[Live2DPipelineKey(blendMode: blendMode, masked: masked)] = try Self
                        .makePipeline(
                            device: device,
                            library: library,
                            blendMode: blendMode,
                            masked: masked
                        )
                }
            }
        } catch {
            logger.info("v-tuber: Failed to create pipeline: \(error)")
            return nil
        }
        let attributes = [kCVMetalTextureUsage: MTLTextureUsage([.renderTarget, .shaderRead]).rawValue]
        CVMetalTextureCacheCreate(kCFAllocatorDefault, attributes as CFDictionary, device, nil, &textureCache)
    }

    private static func makePipeline(device: MTLDevice,
                                     library: MTLLibrary,
                                     blendMode: AyagamiBlendMode,
                                     masked: Bool) throws -> MTLRenderPipelineState
    {
        let constants = MTLFunctionConstantValues()
        var useMask = masked
        constants.setConstantValue(&useMask, type: .bool, index: 0)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "live2DVertex")
        descriptor.fragmentFunction = try library.makeFunction(
            name: "live2DFragment",
            constantValues: constants
        )
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = .bgra8Unorm
        attachment.isBlendingEnabled = true
        switch blendMode {
        case .normal:
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        case .add:
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .one
            attachment.sourceAlphaBlendFactor = .zero
            attachment.destinationAlphaBlendFactor = .one
        case .multiply:
            attachment.sourceRGBBlendFactor = .destinationColor
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .zero
            attachment.destinationAlphaBlendFactor = .one
        }
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeMaskPipeline(device: MTLDevice,
                                         library: MTLLibrary) throws -> MTLRenderPipelineState
    {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "live2DVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "live2DMaskFragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = .r8Unorm
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceColor
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func makeClipTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeOutputTexture(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache else {
            return nil
        }
        var texture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache,
                                                  pixelBuffer,
                                                  nil,
                                                  .bgra8Unorm,
                                                  CVPixelBufferGetWidth(pixelBuffer),
                                                  CVPixelBufferGetHeight(pixelBuffer),
                                                  0,
                                                  &texture)
        guard let texture else {
            return nil
        }
        return CVMetalTextureGetTexture(texture)
    }

    func render(model: AyagamiModel, into pixelBuffer: CVPixelBuffer) {
        guard let outputTexture = makeOutputTexture(pixelBuffer: pixelBuffer),
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }
        var states: [AyagamiArtMeshState?] = []
        for uid in 0 ..< UInt32(artMeshes.count) {
            let state = model.artMeshState(uid)
            if let state, state.visible, !state.vertices.isEmpty {
                vertexBuffer.contents()
                    .advanced(by: artMeshes[Int(uid)].info.texcoordOffset * 8)
                    .copyMemory(from: state.vertices.baseAddress!, byteCount: state.vertices.count * 4)
            }
            states.append(state)
        }
        let drawOrder = model.drawOrder().filter { uid in
            guard let state = states[Int(uid)] else {
                return false
            }
            return state.visible && state.opacity > 0 && !state.vertices.isEmpty
        }
        var usedClipSets = Set<Int>()
        for uid in drawOrder {
            if let clipSet = artMeshes[Int(uid)].clipSet {
                usedClipSets.insert(clipSet)
            }
        }
        for index in usedClipSets.sorted() {
            renderClipSet(index: index,
                          states: states,
                          commandBuffer: commandBuffer,
                          width: outputTexture.width,
                          height: outputTexture.height)
        }
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = outputTexture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }
        encoder.setFrontFacing(.counterClockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(texcoordBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<Live2DVertexUniforms>.stride, index: 2)
        for uid in drawOrder {
            let artMesh = artMeshes[Int(uid)]
            guard let state = states[Int(uid)],
                  let pipeline = pipelines[Live2DPipelineKey(blendMode: artMesh.info.blendMode,
                                                             masked: artMesh.clipSet != nil)]
            else {
                continue
            }
            encoder.setRenderPipelineState(pipeline)
            var uniforms = Live2DFragmentUniforms(multiplyColor: state.multiplyColor,
                                                  opacity: state.opacity,
                                                  screenColor: state.screenColor,
                                                  invertMask: artMesh.info.invertMask ? 1 : 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Live2DFragmentUniforms>.stride, index: 0)
            encoder.setFragmentTexture(textures[artMesh.info.textureIndex], index: 0)
            if let clipSet = artMesh.clipSet {
                encoder.setFragmentTexture(clipSets[clipSet].texture, index: 1)
            }
            draw(encoder: encoder, artMesh: artMesh.info)
        }
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func renderClipSet(index: Int,
                               states: [AyagamiArtMeshState?],
                               commandBuffer: MTLCommandBuffer,
                               width: Int,
                               height: Int)
    {
        if let texture = clipSets[index].texture, texture.width != width || texture.height != height {
            clipSets[index].texture = nil
        }
        if clipSets[index].texture == nil {
            clipSets[index].texture = makeClipTexture(width: width, height: height)
        }
        guard let texture = clipSets[index].texture else {
            return
        }
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }
        encoder.setFrontFacing(.counterClockwise)
        encoder.setRenderPipelineState(maskPipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(texcoordBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<Live2DVertexUniforms>.stride, index: 2)
        for uid in clipSets[index].targets {
            guard let state = states[Int(uid)], state.visible, !state.vertices.isEmpty else {
                continue
            }
            let artMesh = artMeshes[Int(uid)].info
            encoder.setFragmentTexture(textures[artMesh.textureIndex], index: 0)
            draw(encoder: encoder, artMesh: artMesh)
        }
        encoder.endEncoding()
    }

    private func draw(encoder: MTLRenderCommandEncoder, artMesh: AyagamiArtMeshInfo) {
        encoder.setCullMode(artMesh.culling ? .front : .none)
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: artMesh.indexRange.count,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset: artMesh.indexRange.lowerBound * 2,
                                      instanceCount: 1,
                                      baseVertex: artMesh.texcoordOffset,
                                      baseInstance: 0)
    }
}
