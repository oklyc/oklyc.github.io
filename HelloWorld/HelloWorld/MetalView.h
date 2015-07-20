//
//  MetalView.h
//  HelloWorld
//
//  Created by Warren Moore on 8/19/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface MetalView : UIView

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, weak) CAMetalLayer *metalLayer;

@end
