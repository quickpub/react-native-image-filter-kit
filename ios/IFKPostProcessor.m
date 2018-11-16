#import "IFKPostProcessor.h"
#import "IFKInputConverter.h"
#import "Image/RCTImageUtils.h"
#import "NSArray+FilterMapReduce.h"

@interface UIImage (React)

@property (nonatomic, copy) CAKeyframeAnimation *reactKeyframeAnimation;

@end

@interface IFKPostProcessor ()

@property (nonatomic, strong) CIFilter *filter;
@property (nonatomic, strong) NSString *postProcessorCacheKey;
@property (nonatomic, strong) NSString *mainImageName;

@end

@implementation IFKPostProcessor

- (nonnull instancetype)initWithName:(nonnull NSString *)name
                               width:(CGFloat)width
                              height:(CGFloat)height
                       mainImageName:(NSString *)mainImageName
                              inputs:(nonnull NSDictionary *)inputs;
{
  static NSArray<NSString *> *skippedInputs;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    skippedInputs = @[@"disableCache", @"name"];
  });
  
  if ((self = [super init])) {
    _filter = [CIFilter filterWithName:name];
    _postProcessorCacheKey = name;
    _mainImageName = mainImageName;
    
    IFKInputConverter *converter = [[IFKInputConverter alloc] initWithWidth:width height:height];
    NSArray<NSString *> *sortedNames = [[[inputs allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
      return [obj1 compare:obj2];

    }] filter:^BOOL(NSString *val, int idx) {
      return ![skippedInputs containsObject:val];
    }];
    
    for (NSString *inputName in sortedNames) {
      NSObject *value = [converter convertAny:[inputs objectForKey:inputName]];

      [_filter setValue:value forKey:inputName];
      _postProcessorCacheKey = [NSString stringWithFormat:@"%@_%@", _postProcessorCacheKey, value];
    }
  }
  
  return self;
}

- (nonnull UIImage *)process:(nonnull UIImage *)image resizeMode:(RCTResizeMode)resizeMode
{
  CIImage *tmp = [[CIImage alloc] initWithImage:image];
  [_filter setValue:tmp forKey:_mainImageName];
  
  CGRect outputRect = tmp.extent;
  
  CGImageRef cgim = [[self context] createCGImage:_filter.outputImage fromRect:outputRect];
  
  UIImage *filteredImage = [IFKPostProcessor resizeImageIfNeeded:[UIImage imageWithCGImage:cgim]
                                                         srcSize:outputRect.size
                                                        destSize:image.size
                                                           scale:image.scale
                                                      resizeMode:resizeMode];
  
  CGImageRelease(cgim);
  
  return filteredImage;
}

- (nonnull CIContext *)context
{
  static dispatch_once_t initToken;
  static dispatch_once_t contextWithColorManagementToken;
  static dispatch_once_t contextToken;
  
  static EAGLContext *eaglContext;
  static NSArray<NSString *> *filtersWithColorManagement;
  static CIContext *context;
  static CIContext *contextWithColorManagement;
  
  dispatch_once(&initToken, ^{
    filtersWithColorManagement = @[@"CIColorMatrix", @"CIColorInvert", @"CIColorPolynomial"];
    
    eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3]
      ?: [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  });
  
  if ([filtersWithColorManagement some:^BOOL(NSString *val, int idx) {
    return [val isEqualToString:_filter.name];
  }]) {
    dispatch_once(&contextWithColorManagementToken, ^{
      contextWithColorManagement = [CIContext contextWithEAGLContext:eaglContext options:nil];
    });
    
    return contextWithColorManagement;
    
  } else {
    dispatch_once(&contextToken, ^{
      context = [CIContext contextWithEAGLContext:eaglContext
                                          options:@{kCIImageColorSpace: [NSNull null],
                                                    kCIImageProperties: [NSNull null],
                                                    kCIContextWorkingColorSpace: [NSNull null]}];
    });
    
    return context;
  }
}


+ (nonnull UIImage *)resizeImageIfNeeded:(nonnull UIImage *)image
                                 srcSize:(CGSize)srcSize
                                destSize:(CGSize)destSize
                                   scale:(CGFloat)scale
                              resizeMode:(RCTResizeMode)resizeMode
{
  //  RCTLog(@"filter: sizes %@ -> %@", [NSValue valueWithCGSize:srcSize], [NSValue valueWithCGSize:destSize]);
  if (CGSizeEqualToSize(destSize, CGSizeZero) ||
      CGSizeEqualToSize(srcSize, CGSizeZero) ||
      CGSizeEqualToSize(srcSize, destSize)) {
    return image;
  }
  
  CAKeyframeAnimation *animation = image.reactKeyframeAnimation;
  CGRect targetRect = RCTTargetRect(srcSize, destSize, scale, resizeMode);
  //  RCTLog(@"filer: srcSize %@", [NSValue valueWithCGSize:srcSize]);
  //  RCTLog(@"filer: destSize %@", [NSValue valueWithCGSize:destSize]);
  //  RCTLog(@"filer: resizeMode %@", [RNFilterPostProcessor resize:resizeMode]);
  //  RCTLog(@"filer: targetRect %@", [NSValue valueWithCGRect:targetRect]);
  CGAffineTransform transform = RCTTransformFromTargetRect(srcSize, targetRect);
  image = RCTTransformImage(image, destSize, scale, transform);
  image.reactKeyframeAnimation = animation;
  
  return image;
}

@end
