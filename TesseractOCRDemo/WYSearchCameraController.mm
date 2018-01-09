//
//  WYImagePickerController.m
//  Weiyun
//
//  Created by kintan on 2017/3/9.
//  Copyright © 2017年 Tencent Inc. All rights reserved.
//

#import "WYSearchCameraController.h"
#import <AVFoundation/AVFoundation.h>
//#import "Masonry.h"
//#import "WYWireframeView.h"
#import <TesseractOCR/TesseractOCR.h>
//#import "WYSearchScanViewController.h"
//#import "GridView.h" //临时添加的
//#import "CircularLoaderView.h" //临时添加的
//#import "WYKit+Category.h"
//#import "ResultViewController.h"


//@interface CameraButton : UIButton
//- (void)setBackgroundColor:(UIColor *)backgroundColor forState:(UIControlState)state;
//@end
//
//@implementation CameraButton
//
//- (void)setBackgroundColor:(UIColor *)backgroundColor forState:(UIControlState)state {
//    [self setBackgroundImage:[self imageWithColor:backgroundColor] forState:state];
//}
//
//- (UIImage *)imageWithColor:(UIColor *)color {
//    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
//    UIGraphicsBeginImageContext(rect.size);
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    
//    CGContextSetFillColorWithColor(context, [color CGColor]);
//    CGContextFillRect(context, rect);
//    
//    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    
//    return image;
//}


//@end

@interface CharSacn2View : UIView

@property (nonatomic, strong) UIImageView *animationLineImageView;

@end

@implementation CharSacn2View

- (UIImageView *)animationLineImageView {
    if (!_animationLineImageView) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_cursor"]];//ic_ocr_scan_mask  ic_cursor
        _animationLineImageView = iv;
    }
    
    return _animationLineImageView;
}

- (void)startAnimation {
    CABasicAnimation *animation1 = [CABasicAnimation animationWithKeyPath:@"position"];
    NSValue *beginRect1 = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width/2, 0)];
    NSValue *endRect1 = [NSValue valueWithCGPoint:CGPointMake(self.frame.size.width/2, self.frame.size.height)];
    self.animationLineImageView.frame = CGRectMake(0, 100, self.frame.size.width, 3.5);
    [self addSubview:self.animationLineImageView];
    animation1.fromValue = beginRect1;
    animation1.toValue = endRect1;
    
    CAAnimationGroup *lazergroup = [CAAnimationGroup animation];
    lazergroup.animations = @[animation1];
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



@interface WYSearchCameraController ()<UINavigationControllerDelegate, CAAnimationDelegate, G8TesseractDelegate>
//捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
//输出图片
@property (nonatomic ,strong) AVCaptureStillImageOutput *imageOutput;
//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic, strong) AVCaptureSession *session;
//图像预览层，实时显示捕获的图像
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic ,strong) UIView *previewView;


@property (nonatomic, strong) CALayer *lineLayer;
@property(nonatomic,strong) CAShapeLayer *progressLayer;
@property (nonatomic,strong) NSTimer *timer;  // 用来显示动画label
@property (nonatomic, strong) UIScrollView *scrollView; // 用来显示动画label

/*********************华丽的分割线*********************/
@property (nonatomic ,strong) UIImageView *showImageView;
@property (nonatomic, strong) CharSacn2View * charScanView;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, assign) BOOL hasCamera; //是否已经拍照
@property (nonatomic, assign) BOOL hasCancelRecg; //是否取消识别
@property (nonatomic, strong) UIButton *cameraButton;

@end


@implementation WYSearchCameraController

- (void)dealloc {
}


-(UIImageView *)showImageView {
    
    if(!_showImageView) {
        UIImageView *view = [[UIImageView alloc] init];
        view.backgroundColor = [UIColor yellowColor];
        view.contentMode = UIViewContentModeScaleToFill;
       
        
        _showImageView = view;
    }
    
    return _showImageView;
}







#define kNavigationBarBackIconImage [UIImage imageNamed:@"navbar_ic_back.png"]

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        switch (status) {
            case AVAuthorizationStatusNotDetermined:
                // 许可对话没有出现，发起授权许可
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:nil];
                break;
            case AVAuthorizationStatusDenied:
                // 用户明确地拒绝授权，
                //[WYMessageTip tip:@"为了拍照，请在系统设置-隐私-相机中打开微云开关"];
                break;
            default:
                break;
        }
    }
    
 /*   UIButton *flashButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [flashButton setImage: [UIImage imageNamed:@"ic_lamp_close"] forState:UIControlStateNormal];
    [flashButton setImage: [UIImage imageNamed:@"ic_lamp"] forState:UIControlStateSelected];
    flashButton.userInteractionEnabled = true;
    [flashButton addTarget:self action:@selector(flashAction:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *flashButtonItem = [[UIBarButtonItem alloc] initWithCustomView:flashButton];
    self.navigationItem.rightBarButtonItem  = flashButtonItem;
    
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 24, 40)];
    [backButton setImage: [UIImage imageNamed:@"navbar_ic_back"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(cancelCamera) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    UIBarButtonItem *fixedButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                 target:nil action:nil];
    fixedButton.width = -5;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.navigationItem.leftBarButtonItems  = @[fixedButton, backButtonItem];
    UIView *toolBar=[UIView new];
    toolBar.backgroundColor = [UIColor colorWithRed:46.0f/255.0f green:147.0f/255.0f blue:184.0f/255.0f alpha:1];
    
    UILabel *cameraLabel = [UILabel new];//照相机按钮周围的白圈
    cameraLabel.backgroundColor = [UIColor clearColor];
    cameraLabel.layer.borderColor = [UIColor whiteColor].CGColor;
    cameraLabel.layer.borderWidth = 3.0;
    cameraLabel.layer.cornerRadius = 30;
    [toolBar addSubview: cameraLabel];
    [cameraLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(toolBar.mas_centerX);
        make.centerY.mas_equalTo(toolBar.mas_centerY);
        make.width.mas_equalTo(60);
        make.height.mas_equalTo(60);
    }];
    
    self.cameraButton = [UIButton new]; //照相机按钮
    self.cameraButton.backgroundColor = [UIColor whiteColor];
    
    self.cameraButton.layer.cornerRadius = 25;
    [self.cameraButton addTarget:self action:@selector(clickCamera:) forControlEvents:UIControlEventTouchUpInside];
    [toolBar addSubview: self.cameraButton];
    [self.cameraButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(toolBar.mas_centerX);
        make.centerY.mas_equalTo(toolBar.mas_centerY);
        make.width.mas_equalTo(50);
        make.height.mas_equalTo(50);
    }];

    [self.view addSubview:toolBar]; // 添加工具栏
    [toolBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.view);
        make.bottom.equalTo(self.view);
        make.left.mas_equalTo(0);
        make.height.mas_equalTo(70);
    }];
    
    //拍照层
    self.previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.previewView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.previewView];
    [self.previewView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.bottom.equalTo(toolBar.mas_top);
    }];
    
    UITapGestureRecognizer *focusGr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTapAction:)];
    self.previewView.userInteractionEnabled = YES;
    [self.previewView addGestureRecognizer:focusGr];
    
    //创建聚焦动画
    self.progressLayer = [CAShapeLayer layer];
    self.progressLayer.fillColor = [UIColor clearColor].CGColor;
    self.progressLayer.lineWidth = 2.0f;
    self.progressLayer.strokeColor = [UIColor whiteColor].CGColor;
    [self.view.layer addSublayer:self.progressLayer];
    self.progressLayer.hidden = YES;
    
    //滚动提示
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 180, 26)];
    self.scrollView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height - 65 - 40);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    for(int i = 0; i < 20; i++) {
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 26*i, 180, 26)];
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.font = [UIFont systemFontOfSize:14];
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.text = i%2==0 ? @"拍摄文本，识别文字":@"请将手机正对文本";
        textLabel.textColor = [UIColor whiteColor];
        [self.scrollView addSubview:textLabel];
    }
    
    [self.view addSubview:self.scrollView];
    
    [self cameraDistrict];
    //设置导航条的颜色
    [self.navigationController.navigationBar setBarTintColor:[UIColor colorWithRed:46.0f/255.0f green:147.0f/255.0f blue:184.0f/255.0f alpha:0.5]];
    
    //拍照之后显示照片
    [self.view addSubview:self.showImageView];
    self.showImageView.hidden = YES;
    [self.showImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.bottom.equalTo(toolBar.mas_top);
    }];
    
    //照片之上的扫描动画
    self.charScanView = [[CharSacnView alloc] init];
    [self.view addSubview:self.charScanView];
    self.charScanView.hidden = YES;
    self.charScanView.backgroundColor = [UIColor clearColor];
    [self.charScanView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.bottom.equalTo(toolBar.mas_top);
    }];
    
    //扫描动画上面的进度百分比
    self.progressLabel = [UILabel new];
    self.progressLabel.text = @"00%";
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.textColor = [UIColor blackColor];
    self.progressLabel.font = [UIFont systemFontOfSize:36];
    self.progressLabel.hidden = YES;
    [self.view addSubview:self.progressLabel];
    [self.progressLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.mas_equalTo(self.view.mas_centerY);
        make.width.mas_equalTo(100);
        make.height.mas_equalTo(100);
    }];*/
}

//滚动Label 用到的
-(void) nextLabel
{
    CGPoint oldPoint = self.scrollView.contentOffset;
    oldPoint.y += self.scrollView.frame.size.height;
    if(oldPoint.y > 100*self.scrollView.frame.size.height) {
        oldPoint.y = 0;
        [self.scrollView setContentOffset:oldPoint animated:NO];
    }else {
        [self.scrollView setContentOffset:oldPoint animated:YES];
    }
}


-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if(!self.timer) {
        self.timer = [NSTimer timerWithTimeInterval:3.0 target:self selector:@selector(nextLabel) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
    
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
    self.hasCancelRecg = YES;
    self.hasCamera = NO;
    
    self.cameraButton.backgroundColor = [UIColor whiteColor];
    self.cameraButton.selected = NO;
    
    if (self.timer.isValid) {
        [self.timer invalidate];  // 从运行循环中移除， 对运行循环的引用进行一次 release
        self.timer=nil;            // 将销毁定时器
    }
    
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
    
    NSLog(@"sdf");
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
    
    //输入输出设备结合
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddOutput:self.imageOutput]) {
        [self.session addOutput:self.imageOutput];
    }
    //预览层的生成
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.previewView.layer addSublayer:self.previewLayer];
    if ([self.device lockForConfiguration:nil]) {
        //默认关闭闪光灯，
        if ([self.device isFlashModeSupported:AVCaptureFlashModeOff]) {
            [self.device setFlashMode:AVCaptureFlashModeOff];
        }
        
        //自动持续白平衡
        if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        
        //持续自动对焦
        if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [self.device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        
        //持续自动曝光
        if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [self.device setExposurePointOfInterest:CGPointMake(0.5f, 0.5f)];// 曝光点为中心
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


#pragma mark - action

//点击闪光灯按钮
- (void)flashAction:(UIButton*)button {
    if ([self.device lockForConfiguration:nil]) {
        AVCaptureFlashMode toMode = button.selected ? AVCaptureFlashModeOff : AVCaptureFlashModeAuto;
        if ([self.device isFlashModeSupported:toMode]) {
            [self.device setFlashMode:toMode];
            button.selected = !button.isSelected;
        }
        
        [self.device unlockForConfiguration];
    }
}

//点击拍照按钮
- (void)clickCamera:(UIButton *) button {
    
    if(button.selected) {
        return;
    }
    
    button.backgroundColor = [UIColor lightGrayColor];
    button.selected = YES;
    
    AVCaptureConnection *conntion = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!conntion) {
        NSLog(@"拍照失败!");
        return;
    }
    
    __weak typeof(self) weakself = self;
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:conntion completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        __strong typeof(self) strongself = weakself;
        if(!strongself){
            NSLog(@"strongself!!!!!");
            return;
        }
        
        if (imageDataSampleBuffer == nil) {
            return ;
        }
        
        strongself.hasCamera = YES;
        strongself.hasCancelRecg = NO;
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *aImage = [UIImage imageWithData:imageData];

        if (aImage.size.height / aImage.size.width > ([[UIScreen mainScreen] bounds].size.height -44-70) / [[UIScreen mainScreen] bounds].size.width) { //高度太高的剪裁一下
            CGRect rect = CGRectMake(0, 0, aImage.size.width, aImage.size.width * ([[UIScreen mainScreen] bounds].size.height - 70 - 44) / [[UIScreen mainScreen] bounds].size.width);
//            rect.origin.y = (aImage.size.height - rect.size.height) / 2;
            rect.origin.y = 44* aImage.size.height/[[UIScreen mainScreen] bounds].size.height;
//            aImage = [aImage clipRect:rect];
        }

        //把该露的露出来
        self.showImageView.image = aImage;
        self.showImageView.hidden = NO;
        [self.showImageView setNeedsDisplay];
        self.charScanView.hidden = NO;
        [self.charScanView startAnimation];
        self.progressLabel.hidden = NO;
        
        
        //把照相机取景停掉
        if (TARGET_IPHONE_SIMULATOR) {
            
        } else {
            [self.session stopRunning];
        }
        
        
        //压缩图片 
        UIImage *newimage = [aImage g8_blackAndWhite]; //先变黑白
        NSData *tempImageData = UIImageJPEGRepresentation(newimage, 0.5);
        UIImage* finalImage = [UIImage imageWithData: tempImageData];
        
        //开始扫描
        __weak typeof(self) weakself = self;
        dispatch_async( dispatch_get_global_queue(0, 0), ^{
            __strong typeof(self) strongself = weakself;
            if(strongself) {
                G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"chi_sim"];
                tesseract.delegate = strongself;
                tesseract.image = finalImage;
                tesseract.maximumRecognitionTime =  150.0;
                [tesseract recognize];
                dispatch_async( dispatch_get_main_queue(), ^{
                    __strong typeof(self) ssself = weakself;
                    if(ssself) {
                        
                        //跳转到结果页面 
                        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
                        [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal]; //设置对齐方式
                        layout.minimumInteritemSpacing = 1.0f; //cell间距
                        layout.minimumLineSpacing = 1.0f; //cell行距
                       /* ResultViewController* viewController = [[ResultViewController alloc] initWithCollectionViewLayout:layout];
                        viewController.result = [tesseract recognizedText];
                        viewController.baseSession = ssself.baseSession;
                        [ssself.navigationController pushViewController:viewController animated:YES];*/
                    }
                });
            }
        });
        
        
        
        
        
//        WYSearchScanViewController *viewController = [WYSearchScanViewController new];
//        viewController.scanImage = aImage;
//        viewController.baseSession = self.baseSession;
//        [self.navigationController pushViewController:viewController animated:YES];
    }];
}


- (void)progressImageRecognitionForTesseract:(G8Tesseract *)tesseract
{
    __weak typeof(self) weakself = self;
    dispatch_async( dispatch_get_main_queue(), ^{
        __strong typeof(self) strongself = weakself;
        if(strongself) {
            NSLog(@"progress=%ld",tesseract.progress);
            
            
            NSString * ss = [NSString stringWithFormat:@"%d%%",tesseract.progress];
            strongself.progressLabel.text = ss;
        }
    });
}

- (BOOL)shouldCancelImageRecognitionForTesseract:(G8Tesseract *)tesseract
{
    NSLog(@"ddddd   ... sdf");
    return self.hasCancelRecg;
}



- (void)cancelCamera {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showPhotoPicker {
//    WYImagePickerController *picker = [[WYImagePickerController alloc] init];
//    picker.delegate = (id)self;
//    picker.title = @"相册";
//    
//    picker.customDoneButtonTitle = @"完成";
//    picker.customCancelButtonTitle = @"取消";
//    
//    picker.colsInPortrait = 4;
//    picker.colsInLandscape = 5;
//    picker.minimumInteritemSpacing = 2.0;
//    
//    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - WYImagePickerControllerDelegate

//- (void)assetsPickerController:(WYImagePickerController *)picker didFinishPickingAssets:(NSArray *)assets {
//    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
//    
//    PHImageManager *imageManager = [PHImageManager defaultManager];
//    PHAsset *asset = assets.firstObject;
//    CGSize targetSize = [UIScreen mainScreen].bounds.size;
//    targetSize.height = targetSize.height * [UIScreen mainScreen].scale;
//    targetSize.width = targetSize.width * [UIScreen mainScreen].scale;
//    
//    PHImageRequestOptions *options = [PHImageRequestOptions new];
//    options.resizeMode             = PHImageRequestOptionsResizeModeFast;
//    options.deliveryMode           = PHImageRequestOptionsDeliveryModeHighQualityFormat;
//    options.version                = PHImageRequestOptionsVersionCurrent;
//    
//    @weakify(self);
//    [imageManager requestImageForAsset:asset
//                            targetSize:targetSize
//                           contentMode:PHImageContentModeAspectFill
//                               options:options
//                         resultHandler:^(UIImage *result, NSDictionary *info) {
//                             @strongify(self); if (!self) block_return;
//                             if (result) {
//                                 UIImage *photo = result;
//                                 WYSearchScanViewController *viewController = [WYSearchScanViewController new];
//                                 viewController.scanImage = photo;
//                                 viewController.isFromImagePicker = YES;
//                                 [self.navigationController pushViewController:viewController animated:true];
//                             } else{
//                                 [WYMessageTip error:@"选图出错"];
//                             }
//                         }];
//}
//
@end
