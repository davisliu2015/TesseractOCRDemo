//
//  CameraViewController.m
//  TesseractOCRDemo
//
//  Created by davisliu on 2018/1/2.
//  Copyright © 2018年 davisliu. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <TesseractOCR/TesseractOCR.h>
#import "CameraViewController.h"
#import "ResultViewController.h"
#import "Masonry.h"

#define CAMERAVIEW_NAVIGATION_HEIGHT (44 + 20)
#define CAMERAVIEW_TOOLBAR_HEIGHT 96


@interface UIImage(ToolKit)

@end


@implementation UIImage(ToolKit)

- (UIImage *)fixOrientationImage {
    UIImage *aImage = self;
    if (aImage.imageOrientation == UIImageOrientationUp){
        return aImage;
    }

    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }

    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg scale:aImage.scale orientation:0];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

- (UIImage *)clipRect:(CGRect)rect {
    UIImage *aImage = [self fixOrientationImage];
    rect.size.width     *= aImage.scale;
    rect.size.height    *= aImage.scale;
    rect.origin.x       *= aImage.scale;
    rect.origin.y       *= aImage.scale;
    CGImageRef subImage =  CGImageCreateWithImageInRect(aImage.CGImage,rect);
    UIImage *newImage = [UIImage imageWithCGImage:subImage scale:aImage.scale orientation:aImage.imageOrientation];
    CGImageRelease(subImage);
    return newImage;
}

@end


@interface CharSacnView : UIView
@property (nonatomic, strong) UIImageView *animationLineImageView;
@end

@implementation CharSacnView

- (UIImageView *)animationLineImageView {
    if (!_animationLineImageView) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_cursor"]];
        _animationLineImageView = iv;
    }
    
    return _animationLineImageView;
}

- (void)startAnimation {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    NSValue *beginRect = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width/2, 0)];
    NSValue *endRect = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width/2, self.frame.size.height)];
    self.animationLineImageView.frame = CGRectMake(0, 100, self.frame.size.width, 3.5);
    [self addSubview:self.animationLineImageView];
    animation.fromValue = beginRect;
    animation.toValue = endRect;
    CAAnimationGroup *lazergroup = [CAAnimationGroup animation];
    lazergroup.animations = @[animation];
    lazergroup.duration = 1.5;
    lazergroup.autoreverses = NO;
    lazergroup.repeatCount = 100;
    lazergroup.removedOnCompletion = YES;
    lazergroup.fillMode = kCAFillModeForwards;
    [self.animationLineImageView.layer addAnimation:lazergroup forKey:@"animation"];
}

- (void)stopAnimation {
    [_animationLineImageView.layer removeAllAnimations];
    _animationLineImageView.hidden = YES;
}

@end


@interface CameraViewController ()<UINavigationControllerDelegate, CAAnimationDelegate, G8TesseractDelegate>

@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic ,strong) AVCaptureStillImageOutput *imageOutput;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic ,strong) UIView *previewView;
@property (nonatomic, strong) CALayer *lineLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) UIImageView *showImageView;
@property (nonatomic, strong) CharSacnView *charScanView;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, assign) BOOL hasCamera; //是否已经拍照
@property (nonatomic, strong) UIButton *cameraButton;

@end


@implementation CameraViewController

-(UIImageView *)showImageView {
    if(!_showImageView) {
        UIImageView *view = [[UIImageView alloc] init];
        view.contentMode = UIViewContentModeScaleToFill;
        _showImageView = view;
    }
    
    return _showImageView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        switch (status) {
            case AVAuthorizationStatusNotDetermined:
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:nil];
                break;
            case AVAuthorizationStatusDenied:
                break;
            default:
                break;
        }
    }
    
    self.navigationItem.title = @"拍照识别";
    [self.navigationController.navigationBar setBarTintColor:
    [UIColor colorWithRed:46.0f/255.0f green:147.0f/255.0f blue:184.0f/255.0f alpha:0.5]];
    
    UIView *toolBar=[UIView new];
    toolBar.backgroundColor = [UIColor colorWithRed:46.0f/255.0f green:147.0f/255.0f blue:184.0f/255.0f alpha:1];
    UILabel *cameraLabel = [UILabel new];//照相机按钮周围的白圈
    cameraLabel.backgroundColor = [UIColor clearColor];
    cameraLabel.layer.borderColor = [UIColor whiteColor].CGColor;
    cameraLabel.layer.borderWidth = 5.0;
    cameraLabel.layer.cornerRadius = 37.5;
    [toolBar addSubview: cameraLabel];
    [cameraLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(toolBar.mas_centerX);
        make.centerY.mas_equalTo(toolBar.mas_centerY);
        make.width.mas_equalTo(75);
        make.height.mas_equalTo(75);
    }];
     
    self.cameraButton = [UIButton new]; //照相机按钮
    self.cameraButton.backgroundColor = [UIColor whiteColor];
    self.cameraButton.layer.cornerRadius = 30;
    [self.cameraButton addTarget:self action:@selector(clickCamera:) forControlEvents:UIControlEventTouchUpInside];
    [toolBar addSubview: self.cameraButton];
    [self.cameraButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(toolBar.mas_centerX);
        make.centerY.mas_equalTo(toolBar.mas_centerY);
        make.width.mas_equalTo(60);
        make.height.mas_equalTo(60);
    }];
     
     [self.view addSubview:toolBar]; // 底部工具栏
     [toolBar mas_makeConstraints:^(MASConstraintMaker *make) {
     make.width.equalTo(self.view);
     make.bottom.equalTo(self.view);
     make.left.mas_equalTo(0);
     make.height.mas_equalTo(CAMERAVIEW_TOOLBAR_HEIGHT);
     }];
    
    self.previewView = [[UIView alloc] initWithFrame:self.view.bounds];
//    self.previewView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.previewView];//拍照层
    UITapGestureRecognizer *focusGr = [[UITapGestureRecognizer alloc]
                                      initWithTarget:self action:@selector(focusTapAction:)];
    self.previewView.userInteractionEnabled = YES;
    [self.previewView addGestureRecognizer:focusGr];
    [self.previewView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view.mas_top);
        make.left.mas_equalTo(self.view.mas_left);
        make.right.mas_equalTo(self.view.mas_right);
        make.bottom.equalTo(toolBar.mas_top);
    }];
    
    self.progressLayer = [CAShapeLayer layer];
    self.progressLayer.fillColor = [UIColor clearColor].CGColor;
    self.progressLayer.lineWidth = 2.0f;
    self.progressLayer.strokeColor = [UIColor whiteColor].CGColor;
    [self.view.layer addSublayer:self.progressLayer];
    self.progressLayer.hidden = YES;
    [self cameraDistrict];
    
     //拍照之后显示照片
     [self.view addSubview:self.showImageView];
     self.view.backgroundColor = [UIColor purpleColor];
     self.showImageView.hidden = YES;
     [self.showImageView mas_makeConstraints:^(MASConstraintMaker *make) {
         make.top.mas_equalTo(self.view.mas_top).mas_offset(CAMERAVIEW_NAVIGATION_HEIGHT);
         make.left.mas_equalTo(self.view.mas_left);
         make.right.mas_equalTo(self.view.mas_right);
         make.bottom.mas_equalTo(toolBar.mas_top);
     }];
     
     //照片之上的扫描动画
     self.charScanView = [[CharSacnView alloc] init];
     [self.view addSubview:self.charScanView];
     self.charScanView.hidden = YES;
     self.charScanView.backgroundColor = [UIColor clearColor];
     [self.charScanView mas_makeConstraints:^(MASConstraintMaker *make) {
         make.top.mas_equalTo(self.view.mas_top).mas_offset(CAMERAVIEW_NAVIGATION_HEIGHT);
         make.left.mas_equalTo(self.view.mas_left);
         make.right.mas_equalTo(self.view.mas_right);
         make.bottom.equalTo(toolBar.mas_top);
     }];
     
    //扫描动画上面的进度百分比
    self.progressLabel = [UILabel new];
    self.progressLabel.backgroundColor = [UIColor colorWithRed:46.0f/255.0f green:147.0f/255.0f blue:184.0f/255.0f alpha:0.5];
    self.progressLabel.text = @"准备识别";
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.textColor =[UIColor whiteColor];
    self.progressLabel.font = [UIFont systemFontOfSize:18];
    self.progressLabel.hidden = YES;
    self.progressLabel.layer.cornerRadius = 20;
    self.progressLabel.clipsToBounds = YES;
    [self.view addSubview:self.progressLabel];
    [self.progressLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.mas_equalTo(toolBar.mas_top).mas_offset(-80);
        make.width.mas_equalTo(160);
        make.height.mas_equalTo(35);
    }];
}


-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (TARGET_IPHONE_SIMULATOR) {
        self.previewView.backgroundColor = [UIColor lightGrayColor];
    } else {
        //设备取景开始
        [self.session startRunning];
    }
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.showImageView.hidden = YES;
    self.charScanView.hidden = YES;
    self.progressLabel.hidden = YES;
    self.hasCamera = NO;
    self.cameraButton.backgroundColor = [UIColor whiteColor];
    self.cameraButton.selected = NO;
    if (TARGET_IPHONE_SIMULATOR) {
        
    } else {
        [self.session stopRunning];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.previewLayer.frame = self.previewView.frame;
}

- (void)focusTapAction:(UITapGestureRecognizer *)tapGr {
    if(self.hasCamera) {
        return;
    }
    
    CGRect mRect = CGRectZero;
    if ([self.device lockForConfiguration:nil]) {
        if (self.device.isFocusPointOfInterestSupported && [self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            CGPoint point = [tapGr locationInView:tapGr.view];
            mRect = (CGRect){point, CGSizeZero};
            mRect = CGRectInset(mRect, -30, -30);
            point.x /= tapGr.view.bounds.size.width;
            point.y /= tapGr.view.bounds.size.height;
            [self.device setFocusPointOfInterest:point];
            if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                [self.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            }
        }
        
        [self.device unlockForConfiguration];
    }
    
    //绘制初始聚焦图画
    CGPoint point = [tapGr locationInView:tapGr.view];
    UIBezierPath *fromPath = [UIBezierPath bezierPath];
    [fromPath addArcWithCenter:point radius:20 startAngle:0 endAngle:M_PI*2 clockwise:YES];
    self.progressLayer.path = fromPath.CGPath;
    self.progressLayer.hidden = NO;
    
    //绘制终结聚焦图画
    UIBezierPath *toPath = [UIBezierPath bezierPath];
    [toPath addArcWithCenter:point radius:30 startAngle:0 endAngle:M_PI*2 clockwise:YES];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"path"];
    animation.fromValue = (__bridge id _Nullable)(_progressLayer.path);
    animation.toValue = (__bridge id _Nullable)(toPath.CGPath);
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[animation];
    group.duration = .3;
    group.delegate = self;
    group.autoreverses = YES;
    group.repeatCount = 2;
    group.removedOnCompletion = YES;
    group.fillMode = kCAFillModeForwards;
    [_progressLayer addAnimation:group forKey:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.progressLayer.hidden = YES;
    });
}

- (void)cameraDistrict {
    self.device = [self cameraWithPosition:AVCaptureDevicePositionBack]; //使用后置摄像头
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:nil];
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.session = [[AVCaptureSession alloc] init];
    
    do {
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
            self.session.sessionPreset = AVCaptureSessionPreset1920x1080;
            break;
        }
        
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
            self.session.sessionPreset = AVCaptureSessionPreset1280x720;
            break;
        }
        
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            self.session.sessionPreset = AVCaptureSessionPreset640x480;
            break;
        }
        
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset352x288]) {
            self.session.sessionPreset = AVCaptureSessionPreset352x288;
            break;
        }
    } while (0);
    
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddOutput:self.imageOutput]) {
        [self.session addOutput:self.imageOutput];
    }
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.previewView.layer addSublayer:self.previewLayer];
    if ([self.device lockForConfiguration:nil]) {
        if ([self.device isFlashModeSupported:AVCaptureFlashModeOff]) {
            [self.device setFlashMode:AVCaptureFlashModeOff];
        }
        
        if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        
        if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [self.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        
        if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [self.device setExposurePointOfInterest:CGPointMake(0.5f, 0.5f)];
            [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        
        [self.device unlockForConfiguration];
    }
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if (device.position == position ){
            return device;
        }
    return nil;
}


- (void)clickCamera:(UIButton *) button {
    if(button.selected) {
        return;
    }
    
    button.selected = YES;
    button.backgroundColor = [UIColor lightGrayColor];
    AVCaptureConnection *conntion = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!conntion) {
        NSLog(@"拍照失败!");
        return;
    }
    
    __weak typeof(self) weakself = self;
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:conntion
    completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        __strong typeof(self) strongself = weakself;
        if(!strongself){
            return;
        }
        
        if (imageDataSampleBuffer == nil) {
            return;
        }
        
        strongself.hasCamera = YES;
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *aImage = [UIImage imageWithData:imageData];
        if (aImage.size.height / aImage.size.width >
            ([[UIScreen mainScreen] bounds].size.height - CAMERAVIEW_NAVIGATION_HEIGHT - CAMERAVIEW_TOOLBAR_HEIGHT) /
            [[UIScreen mainScreen] bounds].size.width) { //剪裁图片
            CGRect rect = CGRectMake(0, 0, aImage.size.width, aImage.size.width *
                          ([[UIScreen mainScreen] bounds].size.height - CAMERAVIEW_NAVIGATION_HEIGHT - CAMERAVIEW_TOOLBAR_HEIGHT) /
                          [[UIScreen mainScreen] bounds].size.width);
            rect.origin.y = (CAMERAVIEW_TOOLBAR_HEIGHT + 15)* aImage.size.width/[[UIScreen mainScreen] bounds].size.width;
            aImage = [aImage clipRect:rect];
        }
        
        self.showImageView.image = aImage;
        self.showImageView.hidden = NO;
        [self.showImageView setNeedsDisplay];
        self.charScanView.hidden = NO;
        [self.charScanView startAnimation];
        self.progressLabel.hidden = NO;
        if (TARGET_IPHONE_SIMULATOR) {
        } else {
            [self.session stopRunning];
        }
        
        UIImage *newimage = [aImage g8_blackAndWhite]; //处理图片
        NSData *tempImageData = UIImageJPEGRepresentation(newimage, 0.5);
        UIImage* finalImage = [UIImage imageWithData: tempImageData];
        __weak typeof(self) weakself = self; //扫描
        dispatch_async( dispatch_get_global_queue(0, 0), ^{
            __strong typeof(self) strongself = weakself;
            if(strongself) {
                G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"chi_sim"];
                tesseract.delegate = strongself;
                tesseract.image = finalImage;
                tesseract.maximumRecognitionTime =  150.0;
                [tesseract recognize];
                dispatch_async( dispatch_get_main_queue(), ^{
                    __strong typeof(self) strongself = weakself;
                    if(strongself) {
                        ResultViewController *rvc = [ResultViewController new];
                        rvc.text = [tesseract recognizedText];
                        [strongself.navigationController pushViewController:rvc animated:YES];
                    }
                });
            }
        });
    }];
}


- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract
{
    __weak typeof(self) weakself = self;
    dispatch_async( dispatch_get_main_queue(), ^{
        __strong typeof(self) strongself = weakself;
        if(strongself) {
            NSLog(@"progress=%ld",tesseract.progress);
            NSString * ss = [NSString stringWithFormat:@"已识别%d%%",tesseract.progress];
            strongself.progressLabel.text = ss;
        }
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
