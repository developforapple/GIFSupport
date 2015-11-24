//
//  DDGifSupport.h
//  QuizUp
//
//  Created by Normal on 15/11/23.
//  Copyright © 2015年 Bo Wang. All rights reserved.
//

/**
 *  处理gif资源
 */

#ifndef DDAssetsPickerSupport
#define DDAssetsPickerSupport 1
#endif

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#if DDAssetsPickerSupport
#import "DDAssetsPickerViewController.h"
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *const kGifSavedGroupURLKey;

@protocol DDGifSupport <NSObject>
@required
- (BOOL)isGif;
- (nullable NSData *)gifData;
- (nullable UIImage *)gifImage;
@end

@interface DDGifSupport : NSObject

// 保存gif. 不是gif时不作处理
+ (void)saveGifData:(id<DDGifSupport>)data addedToGifGroup:(BOOL)added;

#if DEBUG
// 测试用的。在屏幕上显示这个gif
+ (void)printGifImage:(id<DDGifSupport>)gif;
+ (void)cancelPrintGitImage;
#endif

@end

@interface UIImage (DDGIF)<DDGifSupport>
@end

#if DDAssetsPickerSupport
@interface DDAsset (DDGIF)<DDGifSupport>
@end
#endif

@interface ALAsset (DDGIF)<DDGifSupport>
@end

@interface NSData (DDGIF)<DDGifSupport>
@end

@interface NSString (DDGIF)<DDGifSupport>
@end

NS_ASSUME_NONNULL_END