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
     float total = pattern[8];
     float byteTally;

     byteTally  = pattern[0] / total * smoothstep(min, max, topLeftIntensity);
     byteTally += pattern[1] / total * smoothstep(min, max, topIntensity);
     byteTally += pattern[2] / total * smoothstep(min, max, topRightIntensity);

     byteTally += pattern[3] / total * smoothstep(min, max, leftIntensity);
     byteTally += pattern[4] / total * smoothstep(min, max, rightIntensity);

     byteTally += pattern[5] / total * smoothstep(min, max, bottomLeftIntensity);
     byteTally += pattern[6] / total * smoothstep(min, max, bottomIntensity);
     byteTally += pattern[7] / total * smoothstep(min, max, bottomRightIntensity);

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

    [self setFloat:1.05 forUniformName:@"range"];

    GLfloat pattern[9] = {4, 2, 1, 8, 128, 16, 32, 64, /* range: */ 175}; //standard
//    GLfloat pattern[9] = {32, 64, 128, 16, 1, 8, 4, 2, /* range: */ 175}; //reverse
//    GLfloat pattern[9] = {1, 2, 4, 8, 16, 32, 64, 128, /* range: */ 175}; //more stable
    [self setFloatArray:pattern length:9 forUniform:@"pattern"];

    return self;
}

- (void)setPattern:(GLfloat *)pattern
{
    [self setFloatArray:pattern length:9 forUniform:@"pattern"];
}

@end
