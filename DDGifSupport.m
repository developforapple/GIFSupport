//
//  DDGifSupport.m
//  QuizUp
//
//  Created by Normal on 15/11/23.
//  Copyright © 2015年 Bo Wang. All rights reserved.
//

#import "DDGifSupport.h"
#import <UIImage+GIF.h>

NS_ASSUME_NONNULL_BEGIN

//在NSUserDefaults中保存的gif相册URL的key
NSString *const kGifSavedGroupURLKey = @"kJuYouQuPictureGroupURL";

static NSString *kGifSavedGroupName; //当前gif相册名
static NSString *kGifSavedGroupURL;  //当前gif相册URL

static ALAssetsLibrary *kGifLibrary;  //操作gif的library
static ALAssetsGroup *kGifSavedGroup; //当前gif相册。使用 +gifGroup: 来获取

static NSError *kLastError; //导致出错的error。保存最后一个获取到的

static NSString *kGifSupportErrorDomain = @"GIFERROR";

typedef NS_ENUM(NSUInteger, GIFSupportErrorCode) {
    ERROR_GroupNameConflict = 1001, //组名冲突
    ERROR_GroupEditable = 1002 ,    //无法编辑
};

@implementation DDGifSupport

+ (void)initialize
{
    kGifSavedGroupName = @"GIF";
    kGifLibrary = [[ALAssetsLibrary alloc] init];
}

/**
 *  取得gif相册。如果没有，将创建一个新的分组。
 */
+ (void)gifGroup:(void (^)(ALAssetsGroup *_Nullable group))completion
{
    if (!completion) {
        return;
    }
    
    if (!kGifSavedGroupName) {
        completion(nil);
        return;
    }
    
    if (kGifSavedGroup) {
        completion(kGifSavedGroup);
        return;
    }
    
    // 有没有记录相册URL
    if (!kGifSavedGroupURL) {
        kGifSavedGroupURL = [[NSUserDefaults standardUserDefaults] objectForKey:kGifSavedGroupURLKey];
    }
    
    if (!kGifSavedGroupURL) {
        //没有记录，尝试创建一个新的相册
        [self createGifGroup:completion];
    }else{
        
        NSURL *URL = [NSURL URLWithString:kGifSavedGroupURL];
        [kGifLibrary groupForURL:URL resultBlock:^(ALAssetsGroup *group) {
            completion(group);
        } failureBlock:^(NSError *error) {
            [self createGifGroup:completion];
        }];
    }
}

/**
 *  创建gif相册。
 */
+ (void)createGifGroup:(void (^)( ALAssetsGroup *_Nullable group))completion
{
    if (!completion) {
        return;
    }
    
    [kGifLibrary addAssetsGroupAlbumWithName:kGifSavedGroupName resultBlock:^(ALAssetsGroup *group) {
        if (!group) {
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:ERROR_GroupNameConflict userInfo:@{@"text":@"相册名冲突"}];
            kLastError = error;
        }else{
            NSURL *URL = [group valueForProperty:ALAssetsGroupPropertyURL];
            [[NSUserDefaults standardUserDefaults] setObject:URL.absoluteString forKey:kGifSavedGroupURLKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        completion(group);
    } failureBlock:^(NSError *error) {
        kLastError = error;
        completion(nil);
    }];
}

+ (void)saveGifData:(id<DDGifSupport>)data addedToGifGroup:(BOOL)added
{
    if (!data) {
        return;
    }
    
    NSData *gifData = [data gifData];
    NSDictionary *metadata = @{@"UTI":(__bridge NSString *)kUTTypeGIF};
    
    [kGifLibrary writeImageDataToSavedPhotosAlbum:gifData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error || !assetURL) {
            kLastError = error;
            return;
        }
        
        if (!added) return;
        
        [self gifGroup:^(ALAssetsGroup * _Nullable group) {
            
            if (!group) return;
            
            [kGifLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                if ([group isEditable]) {
                    [group addAsset:asset];
                }else{
                    NSError *err = [NSError errorWithDomain:kGifSupportErrorDomain code:ERROR_GroupEditable userInfo:@{@"text":@"组无法编辑或者为nil"}];
                    kLastError = err;
                }
            } failureBlock:^(NSError *error) {
                kLastError = error;
            }];
            
        }];
    }];
}

#if DEBUG
static UIImageView *imageView;
+ (void)printGifImage:(id<DDGifSupport>)gif
{
    UIImage *gifImage = [gif gifImage];
    
    if (!imageView) {
        imageView = [[UIImageView alloc] init];
    }
    
    imageView.image = gifImage;
    imageView.frame = CGRectMake(0, 0, gifImage.size.width, gifImage.size.height);
    
    if (!imageView.superview) {
        [[[UIApplication sharedApplication] keyWindow] addSubview:imageView];
    }
}

+ (void)cancelPrintGitImage
{
    if (imageView) {
        imageView.image = nil;
        [imageView removeFromSuperview];
    }
}
#endif

@end

#pragma mark - load GIF
@implementation UIImage (DDGIF)
- (BOOL)isGif
{
    return self.images.count>1;
}

- (nullable NSData *)gifData
{
    if (![self isGif]) {
        return nil;
    }
    
    NSData *data = UIImageJPEGRepresentation(self, .95f);
    return data;
}

- (nullable UIImage *)gifImage
{
    if ([self isGif]) {
        return self;
    }
    return nil;
}
@end

#if DDAssetsPickerSupport
@implementation DDAsset (DDGIF)
- (BOOL)isGif
{
    return [self.assets isGif];
}

- (nullable NSData *)gifData
{
    return [self.assets gifData];
}

- (nullable UIImage *)gifImage
{
    return [self.assets gifImage];
}

@end
#endif

@implementation ALAsset (DDGIF)

- (BOOL)isGif
{
    ALAssetRepresentation *re = [self representationForUTI: (__bridge NSString *)kUTTypeGIF];
    return (BOOL)re;
}

- (nullable NSData *)gifData
{
    if (![self isGif]) {
        return nil;
    }
    
    ALAssetRepresentation *re = [self representationForUTI:(__bridge NSString *)kUTTypeGIF];
    long long size = re.size;
    uint8_t *buffer = malloc(size);
    NSError *error;
    NSUInteger bytes = [re getBytes:buffer fromOffset:0 length:size error:&error];
    
    NSData *data = [NSData dataWithBytes:buffer length:bytes];
    
    free(buffer);
    return data;
}

- (nullable UIImage *)gifImage
{
    NSData *data = [self gifData];
    UIImage *gifImage = [UIImage sd_animatedGIFWithData:data];
    return gifImage;
}

@end

@implementation NSData (DDGIF)

- (BOOL)isGif
{
    UIImage *gifImage = [self gifImage];
    return [gifImage isGif];
}

- (nullable NSData *)gifData
{
    return self;
}

- (nullable UIImage *)gifImage
{
    return [UIImage sd_animatedGIFWithData:[self gifData]];
}

@end

@implementation NSString (DDGIF)

- (BOOL)isGif
{
    return [[self pathExtension] isEqualToString:@"gif"];
}

- (nullable NSData *)gifData
{
    NSURL *fileURL = [NSURL fileURLWithPath:self];
    NSData *data;
    if (fileURL) {
        data = [NSData dataWithContentsOfFile:self];
    }else{
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:self]];
    }
    return data;
}

- (nullable UIImage *)gifImage
{
    if ([self isGif]) {
        UIImage *image = [UIImage sd_animatedGIFWithData:[self gifData]];
        return image;
    }
    return nil;
}

@end

NS_ASSUME_NONNULL_END