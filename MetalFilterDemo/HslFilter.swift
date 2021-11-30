//
//  HslFilter.swift
//  MetalFilterDemo
//
//  Created by Preet Minhas on 30/11/21.
//

import Foundation
import MetalKit
import CoreImage

class HslFilter : CIFilter {
    
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    
    var hFactor : Float = 1
    var sFactor : Float = 1
    var lFactor : Float = 1
    
    var inputImage: CIImage?
    
    override init()
    {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var outputImage: CIImage?
    {
        if let inputImage = inputImage
        {
            return imageFromComputeShader(width: inputImage.extent.width,
                                          height: inputImage.extent.height,
                                          inputImage: inputImage)
        }
        return nil
    }
    
    
    func imageFromComputeShader(width: CGFloat, height: CGFloat, inputImage: CIImage) -> CIImage?
    {
        //Initializing all Metal vars here for readability purpose
        //UNOPTIMIZED code. some of these variables can be kept at object level and should ideally be created just once and then reused every cycle:
        // device, ciContext, defaultLibrary, kernelFunction, pipelineState
        // Also, the kernelInputTexture and kernelOutputTexture can be cached at an object level (take care to handle image changes)
        
        let device: MTLDevice = MTLCreateSystemDefaultDevice()!
        let ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false, .name: "HslFilter"])
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: "hslMultiplier")!
        var pipelineState: MTLComputePipelineState!
        do
        {
            //create a compute pipeline state using the kernel function
            pipelineState = try device.makeComputePipelineState(function: kernelFunction)
        }
        catch
        {
            fatalError("Unable to create pipeline state")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("Command Queue not available!")
            return nil
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Command buffer not available!")
            return nil
        }
        
        //create texture descriptor. We will be both reading from and writing to the texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                         width: Int(width),
                                                                         height: Int(height),
                                                                         mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        
        let kernelInputTexture = device.makeTexture(descriptor: textureDescriptor)
        let kernelOutputTexture = device.makeTexture(descriptor: textureDescriptor)
        
        //render the input image to the input texture
        ciContext.render(inputImage,
                         to: kernelInputTexture!,
                         commandBuffer: commandBuffer,
                         bounds: inputImage.extent,
                         colorSpace: colorSpace)
        
        //command encoder to run the compute shader
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("No command encoder!")
            return nil
        }
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        //set the input and output textures
        commandEncoder.setTexture(kernelInputTexture, index: 0)
        commandEncoder.setTexture(kernelOutputTexture, index: 1)
        //bind the buffer elements
        commandEncoder.setBytes(&hFactor, length: MemoryLayout<Float>.stride, index: 0)
        commandEncoder.setBytes(&sFactor, length: MemoryLayout<Float>.stride, index: 1)
        commandEncoder.setBytes(&lFactor, length: MemoryLayout<Float>.stride, index: 2)
        
        //dispatch threadgroups
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        
        //ensure that there are sufficient threadgroups to cover the entire image
        //Refer "Metal: Calculating Threadgroup and Grid Sizes"
        let threadgroupsPerGrid = MTLSize(width: (textureDescriptor.width + w - 1) / w,
                                          height: (textureDescriptor.height + h - 1) / h,
                                          depth: 1)
        
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid,
                                            threadsPerThreadgroup:threadsPerThreadgroup)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
        //Tadaa: done!
        return CIImage(mtlTexture: kernelOutputTexture!,
                       options: [CIImageOption.colorSpace: colorSpace])
    }
    
    override func setDefaults() {
        super.setDefaults()
        self.inputImage = nil
    }
}

