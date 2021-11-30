//
//  HslMultiplierFilter.metal
//  MetalFilterDemo
//
//  Created by Preet Minhas on 30/11/21.
//

#include <metal_stdlib>
using namespace metal;

float3 hue2rgb(float hue){
    hue=fract(hue);
    return saturate(float3(
                           abs(hue*6.-3.)-1.,
                           2.-abs(hue*6.-2.),
                           2.-abs(hue*6.-4.)
                           ));
}

float3 rgb2hsl(float3 c) {
    float cMin=min(min(c.r,c.g),c.b),
    cMax=max(max(c.r,c.g),c.b),
    delta=cMax-cMin;
    float3 hsl=float3(0.,0.,(cMax+cMin)/2.);
    if(delta!=0.0){ //If it has chroma and isn't gray.
        if(hsl.z<.5){
            hsl.y=delta/(cMax+cMin); //Saturation.
        }else{
            hsl.y=delta/(2.-cMax-cMin); //Saturation.
        }
        float deltaR=(((cMax-c.r)/6.)+(delta/2.))/delta,
        deltaG=(((cMax-c.g)/6.)+(delta/2.))/delta,
        deltaB=(((cMax-c.b)/6.)+(delta/2.))/delta;
        //Hue.
        if(c.r==cMax){
            hsl.x=deltaB-deltaG;
        }else if(c.g==cMax){
            hsl.x=(1./3.)+deltaR-deltaB;
        }else{ //if(c.b==cMax){
            hsl.x=(2./3.)+deltaG-deltaR;
        }
        hsl.x=fract(hsl.x);
    }
    return hsl;
}

float3 hsl2rgb(float3 hsl) {
    if(hsl.y==0.){
        return float3(hsl.z); //Luminance.
    }else{
        float b;
        if(hsl.z<.5){
            b=hsl.z*(1.+hsl.y);
        }else{
            b=hsl.z+hsl.y-hsl.y*hsl.z;
        }
        float a=2.*hsl.z-b;
        return a+hue2rgb(hsl.x)*(b-a);
    }
}

//This filter will multiply the image's hsl values with given multipliers
kernel void hslMultiplier(texture2d<float, access::read> srcTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        constant float &hFactor [[buffer(0)]],
                        constant float &sFactor [[buffer(1)]],
                        constant float &lFactor [[buffer(2)]],
                        uint2 id [[thread_position_in_grid]]) {
    //the grid could be greater then out texture, hence exit early if out of bounds
    //Refer "Metal: Calculating Threadgroup and Grid Sizes"
    if (id.x >= outTexture.get_width() || id.y >= outTexture.get_height()) {
        return;
    }
    //read source color
    float4 inColor = srcTexture.read(id);
    //convert to hsl
    float3 hsl = rgb2hsl(inColor.rgb);
    
    //increase value
    hsl *= float3(hFactor, sFactor, lFactor);
    
    //clamp to 0,1
    hsl = clamp(hsl, float3(0), float3(1));
    
    float4 outColor = float4(hsl2rgb(hsl), 1);
    //write to output texture
    outTexture.write(outColor, id);
}
