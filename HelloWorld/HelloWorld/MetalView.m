//
//  MetalView.m
//  HelloWorld
//
//  Created by Warren Moore on 8/19/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import "MetalView.h"

@implementation MetalView
{
    CVMetalTextureCacheRef _textureCache;
    
    /**
     *  metal
     */
    CVMetalTextureCacheRef _metalTextureCache;
    CVMetalTextureRef      _metalTexture;
    
    //pixelBuffer
    CVPixelBufferRef                _screenPixelBuffer;
    
    UIImageView * _iv;
}

+ (id)layerClass
{
    return [CAMetalLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        _metalLayer = (CAMetalLayer *)[self layer];
        _device = MTLCreateSystemDefaultDevice();
        _metalLayer.device = _device;
        _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _metalLayer.framebufferOnly = NO;
    }
    
    return self;
}

- (void)didMoveToWindow
{
    NSLog(@"metallayer.drawablesize.width = %f, metalLayer.drawablesize.height = %f", _metalLayer.drawableSize.width, _metalLayer.drawableSize.height);
    [self setupCaptureScreenTexture];
    
    [self redraw];
}

- (void)redraw
{
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    
    id<MTLTexture> texture = drawable.texture;
    
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0);
    
    id<MTLCommandQueue> commandQueue = [self.device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id <MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [commandEncoder endEncoding];
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    
    //    NSLog(@"metallayer.drawablesize.width = %f, metalLayer.drawablesize.height = %f", _metalLayer.drawableSize.width, _metalLayer.drawableSize.height);
    
    
    id<MTLTexture> tmpTexture = CVMetalTextureGetTexture(_metalTexture);
    //    NSLog(@"drawable.texture.pixelFormat = %d", (int)drawable.texture.pixelFormat);
    //    NSLog(@"pixelFormat = %d", (int)tmpTexture.pixelFormat);
    //    NSLog(@"texture width = %lu, texture.height = %lu", drawable.texture.width, drawable.texture.height);
    
    
    NSLog(@"tmpTexture = %@", tmpTexture);
    MTLOrigin origin = MTLOriginMake(0, 0, 0);
    id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
    [blitCommandEncoder copyFromTexture:drawable.texture
                            sourceSlice:0
                            sourceLevel:0
                           sourceOrigin:origin
                             sourceSize:MTLSizeMake(_metalLayer.drawableSize.width, _metalLayer.drawableSize.height, 1)
                              toTexture:tmpTexture
                       destinationSlice:0
                       destinationLevel:0
                      destinationOrigin:origin];
    
    NSLog(@"drawable.texture = %@", drawable.texture);
    NSLog(@"tmpTexture = %@", tmpTexture);
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    [v setBackgroundColor:[UIColor whiteColor]];
    [self addSubview:v];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    [v addSubview:iv];
    [iv setBackgroundColor:[UIColor blackColor]];
    [iv setImage:[self imageFromPixelBuffer:_screenPixelBuffer]];
    [blitCommandEncoder endEncoding];
}

- (BOOL)setupCaptureScreenTexture
{
    if (!_metalTextureCache) {
        CVReturn err = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                                 NULL,
                                                 _device,
                                                 NULL,
                                                 &_metalTextureCache);
        if (err) {
            return NO;
        }
    }
    
    if (!_screenPixelBuffer) {
        CFDictionaryRef empty; // empty value for attr value.
        CFMutableDictionaryRef attrs;
        empty = CFDictionaryCreate(kCFAllocatorDefault,
                                   NULL,
                                   NULL,
                                   0,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary
        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                          1,
                                          &kCFTypeDictionaryKeyCallBacks,
                                          &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
        
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault,
                                           375,
                                           667,
                                           kCVPixelFormatType_32BGRA,
                                           attrs,
                                           &_screenPixelBuffer);
        
        CFRelease(empty);
        CFRelease(attrs);
        
        if (err)
        {
            return NO;
        }
        
    }
    
    if (!_metalTexture) {
        
        CVReturn err = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                 _metalTextureCache,
                                                                 _screenPixelBuffer,
                                                                 NULL,
                                                                 MTLPixelFormatBGRA8Unorm,
                                                                 375,
                                                                 667,
                                                                 0,
                                                                 &_metalTexture);
        if (err)
        {
            return NO;
        }
    }
    
    return YES;
}

-(UIImage *)imageFromPixelBuffer:(CVImageBufferRef)sampleBuffer
{
    CVImageBufferRef buffer;
    buffer = sampleBuffer;
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    //从 CVImageBufferRef 取得影像的细部信息
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    //利用取得影像细部信息格式化 CGContextRef
    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    //透过 CGImageRef 将 CGContextRef 转换成 UIImage
    CGImageRef cgImage;
    UIImage *image;
    NSLog(@"data前：%@", UIImageJPEGRepresentation(image, 1));
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage];
    NSLog(@"data后：%@", UIImageJPEGRepresentation(image, 1));
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    return image;
    
    //    CVImageBufferRef imageBuffer = sampleBuffer;
    //    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    //    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    //    size_t width = CVPixelBufferGetWidth(imageBuffer);
    //    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    //    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    //    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    //    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    //    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);
    //    UIImage *image = [UIImage imageWithCGImage:cgImage];
    //    CGImageRelease(cgImage);
    //    CGDataProviderRelease(provider);
    //    CGColorSpaceRelease(rgbColorSpace);
    //    NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
    //    image = [UIImage imageWithData:imageData];
    //    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    //    return image;
    
    //    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:sampleBuffer];
    //
    //    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    //    CGImageRef videoImage = [temporaryContext
    //                             createCGImage:ciImage
    //                             fromRect:CGRectMake(0, 0,
    //                                                 CVPixelBufferGetWidth(sampleBuffer),
    //                                                 CVPixelBufferGetHeight(sampleBuffer))];
    //
    //    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
    //    CGImageRelease(videoImage);
    //
    //    return uiImage;
}

@end
