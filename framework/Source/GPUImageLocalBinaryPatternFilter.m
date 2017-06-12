#import "GPUImageLocalBinaryPatternFilter.h"

// This is based on "Accelerating image recognition on mobile devices using GPGPU" by Miguel Bordallo Lopez, Henri Nykanen, Jari Hannuksela, Olli Silven and Markku Vehvilainen
// http://www.ee.oulu.fi/~jhannuks/publications/SPIE2011a.pdf

// Right pixel is the most significant bit, traveling clockwise to get to the upper right, which is the least significant
// If the external pixel is greater than or equal to the center, set to 1, otherwise 0
//
// 2 1 0
// 3   7
// 4 5 6

// 01101101
// 76543210

@implementation GPUImageLocalBinaryPatternFilter

NSString *const kGPUImageLocalBinaryPatternFragmentShaderString = SHADER_STRING
(
 precision highp float;

 varying vec2 textureCoordinate;
 varying vec2 leftTextureCoordinate;
 varying vec2 rightTextureCoordinate;

 varying vec2 topTextureCoordinate;
 varying vec2 topLeftTextureCoordinate;
 varying vec2 topRightTextureCoordinate;

 varying vec2 bottomTextureCoordinate;
 varying vec2 bottomLeftTextureCoordinate;
 varying vec2 bottomRightTextureCoordinate;

 uniform float range;
 uniform float pattern[9];

 uniform sampler2D inputImageTexture;
 const mediump vec3 lu = vec3(0.2125, 0.7154, 0.0721);

 float pixel(vec2 coord) {
     float lum = dot(texture2D(inputImageTexture, coord).rgb, lu);
     return smoothstep(0.001, 0.99, lum);
 }

 void main()
 {
     //intensities
     lowp float topLeftIntensity = pixel(topLeftTextureCoordinate);
     lowp float leftIntensity = pixel(leftTextureCoordinate);
     lowp float bottomLeftIntensity = pixel(bottomLeftTextureCoordinate);

     lowp float topIntensity = pixel(topTextureCoordinate);
     lowp float centerIntensity = pixel(textureCoordinate);
     lowp float bottomIntensity = pixel(bottomTextureCoordinate);

     lowp float topRightIntensity = pixel(topRightTextureCoordinate);
     lowp float rightIntensity = pixel(rightTextureCoordinate);
     lowp float bottomRightIntensity = pixel(bottomRightTextureCoordinate);
     
     float min = centerIntensity / range;
     float max = centerIntensity * range;
     float range = pattern[8];
     float byteTally;

     byteTally  = pattern[0] / range * smoothstep(min, max, topLeftIntensity);
     byteTally += pattern[1] / range * smoothstep(min, max, topIntensity);
     byteTally += pattern[2] / range * smoothstep(min, max, topRightIntensity);

     byteTally += pattern[3] / range * smoothstep(min, max, leftIntensity);
     byteTally += pattern[4] / range * smoothstep(min, max, rightIntensity);

     byteTally += pattern[5] / range * smoothstep(min, max, bottomLeftIntensity);
     byteTally += pattern[6] / range * smoothstep(min, max, bottomIntensity);
     byteTally += pattern[7] / range * smoothstep(min, max, bottomRightIntensity);

     //     byteTally = 1. - pow(byteTally, 1.618);

     // TODO: Replace the above with a dot product and two vec4s
     // TODO: Apply step to a matrix, rather than individually

     gl_FragColor = vec4(byteTally, byteTally, byteTally, 1.0);
 }
);

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageLocalBinaryPatternFragmentShaderString]))
    {
		return nil;
    }

    // 1 4 2 8 16 64 32 128
    // 1 2 4 8 128 64 32 16
    // 1 -1 1 -1 ....
    // 128 1 2 64 4 32 8 16
    // 128 64 32 ...
    //

    [self setFloat:1.001 forUniformName:@"range"];

    GLfloat pattern[9] = {1, 2, 4, 8, 16, 32, 64, 128, /* range: */ 255};
    [self setFloatArray:pattern length:9 forUniform:@"pattern"];

    return self;
}

- (void)setPattern:(GLfloat *)pattern
{
    [self setFloatArray:pattern length:9 forUniform:@"pattern"];
}

@end
