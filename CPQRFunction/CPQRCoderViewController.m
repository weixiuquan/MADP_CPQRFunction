//
//  CPQRCoderViewController.m
//  CocoaPodDemo
//
//  Created by liurenpeng on 7/29/15.
//  Copyright (c) 2015 刘任朋. All rights reserved.
//

#import "CPQRCoderViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
//#import "GlobalDefineConfig.h"
//#import "ZBarReaderViewController.h"
//#import "CPQRFuncitonBundle.h"

#define CPCAPTURE_BOUND  ([UIScreen mainScreen].bounds)
#define CPCAPTURE_WIDTH  (([UIScreen mainScreen].bounds.size.width)/1.5f)
#define CPQR_IOS7 [[[UIDevice currentDevice] systemVersion]floatValue]>=7.0
#define CPQR_IOS8 [[[UIDevice currentDevice] systemVersion]floatValue]>=8.0
#define IPHONEX (CGSizeEqualToSize(CGSizeMake(375.f, 812.f), [UIScreen mainScreen].bounds.size) || CGSizeEqualToSize(CGSizeMake(414.f, 896.f), [UIScreen mainScreen].bounds.size) || CGSizeEqualToSize(CGSizeMake(812.f, 375.f), [UIScreen mainScreen].bounds.size) || CGSizeEqualToSize(CGSizeMake(896.f, 414.f), [UIScreen mainScreen].bounds.size))

#define VideoPreviewLayerFrame  CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height) //self.view.bounds

@interface CPQRCoderViewController() <UIImagePickerControllerDelegate>///<>
@property(nonatomic,assign)BOOL isPhoto;

@end
@implementation CPQRCoderViewController
@synthesize isPhoto;
@synthesize cornerBoarder;
@synthesize cornerLineWidth;
@synthesize abstractLabel;
@synthesize captureButton;
@synthesize scanResult;
@synthesize captureVideoPreviewLayer;
@synthesize captureSession;
@synthesize isScanning;
@synthesize qrCoderView;
@synthesize scanLineView;
@synthesize scanLineAnimation;
@synthesize lampButton;
@synthesize codeRect;
@synthesize scanView;

- (id)initWithResult:(CPScanResult)result{
    self = [super init];
    if (self) {
//        WXLogInfo(@"%s, self.view.bounds=%@", __FUNCTION__, NSStringFromCGRect(self.view.bounds)); //{{0, 0}, {375, 667}}
        
//        if (![self judgeAVCaptureDevice]) {
//            return nil;
//        }
        
        isPhoto = NO;
        self.scanResult = result;
        self.cornerLineWidth = 20.f;
        self.cornerBoarder = 2.f;
        if ([[[UIDevice currentDevice] systemVersion]floatValue]>=7.0) {
            self.codeRect = CGRectMake(CPCAPTURE_BOUND.size.width/2-CPCAPTURE_WIDTH/2, (CPCAPTURE_BOUND.size.height-[self statusNaviTotalHeight]-[self screenBottomSafeMargin]-CPCAPTURE_WIDTH)/2+30, CPCAPTURE_WIDTH, CPCAPTURE_WIDTH);
        }else
        {
            self.codeRect = CGRectMake(CPCAPTURE_BOUND.size.width/2-CPCAPTURE_WIDTH/2, 64, CPCAPTURE_WIDTH, CPCAPTURE_WIDTH);
        }

        
#if TARGET_IPHONE_SIMULATOR
        //模拟器
#else
        //真机
        BOOL isCameraAvailable = [UIImagePickerController
                                  isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];//判断摄像头是否能用
        if (!isCameraAvailable) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"没有可用的相机" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alert show];
            return nil;
        }
#endif

        
        [self settingSystemCapture];
        [self createView];
        [self setLampButtonAttribute]; //闪光灯开关
        [self setAbstractLabelAttribute]; //提示语：将二维码放入框内
        [self setCaptureButtonAttribute];//从相册选择二维码图片进行解码
        [self setBackButtonAttribute]; //屏幕左下角返回按钮
        [self setScanLineViewAttribute];
    }
    
    return self;
}

- (BOOL)judgeAVCaptureDevice
{
    AVCaptureDevice* inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]; //defaultDevice即后置相机
    if(!inputDevice){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"后置相机不可用。" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"此应用程序没有权限来访问您的相机，您可以在手机“设置->隐私->相机”中启用访问。" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        inputDevice = nil;
        captureInput = nil;
        return NO;
    }
    return YES;
}
- (void)setLampButtonAttribute
{
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if([device isTorchModeSupported:device.torchMode]){
        lampButton = [UIButton buttonWithType:UIButtonTypeCustom];
        lampButton.frame = CGRectMake(CPCAPTURE_BOUND.size.width-55, 35, 35, 35);
        [lampButton setImage:[UIImage imageNamed:@"CPQRCode.bundle/images/light_off"] forState:UIControlStateNormal];
        [lampButton setImage:[UIImage imageNamed:@"CPQRCode.bundle/images/light_on"] forState:UIControlStateSelected];
        [lampButton addTarget:self action:@selector(flashLightClick:) forControlEvents:UIControlEventTouchUpInside];
        if (device.torchMode==AVCaptureTorchModeOff) {
            lampButton.selected = NO;
        }else{
            lampButton.selected = YES;
        }
        [self.view addSubview:lampButton];
    }
    
}
- (void)createView
{
    self.qrCoderView = [[CPQRCoderView alloc]initWithFrame:VideoPreviewLayerFrame];
    qrCoderView.captureHeight = self.codeRect.size.height;
    qrCoderView.captureWidth = self.codeRect.size.width;
    qrCoderView.cornerBoarder = self.cornerBoarder;
    qrCoderView.cornerLineWidth = self.cornerLineWidth;
    qrCoderView.codeViewRect = self.codeRect; //设置取景框范围size
    
//    qrCoderView.backgroundColor = [UIColor blackColor];
//    qrCoderView.alpha = 0.5; //页面透明度  0完全透明  1不透明  0.5半透明
    
    qrCoderView.backgroundColor = [UIColor clearColor];
    qrCoderView.alpha = 1; //页面透明度  0完全透明  1不透明 0.5半透明
    
    [self.view addSubview:qrCoderView];
    
    
    //---------------------------------------
    //取景框边角标
    
#if (0)
    //可以在上层再放置一个带8个角标的取景框图片
    self.scanView = [[UIImageView alloc]initWithFrame:self.codeRect];//扫描框 size就是取景框codeRect
    self.scanView.backgroundColor = [UIColor clearColor];
    //self.scanView.image =
    [self.view addSubview:self.scanView];
#endif
    
#if (0)
    //添加取景框区域的8个角标
    UIColor *cornerLineColor = [UIColor greenColor];//[UIColor orangeColor];
    
    //左上角 垂直线
    UIView *leftUpVerticalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x, codeRect.origin.y, cornerBoarder, cornerLineWidth)];
    leftUpVerticalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:leftUpVerticalLine];
    
    //左上角 水平线
    UIView *leftUpHorizontalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x, codeRect.origin.y, cornerLineWidth, cornerBoarder)];
    leftUpHorizontalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:leftUpHorizontalLine];
    
    //左下角 垂直线
    UIView *leftDownVerticalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x, codeRect.origin.y+codeRect.size.height-cornerLineWidth, cornerBoarder, cornerLineWidth)];
    leftDownVerticalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:leftDownVerticalLine];
    
    //左下角 水平线
    UIView *leftDownHorizontalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x, codeRect.origin.y+codeRect.size.height-cornerBoarder, cornerLineWidth, cornerBoarder)];
    leftDownHorizontalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:leftDownHorizontalLine];
    
    //右上角 垂直线
    UIView *rightUpVerticalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x+codeRect.size.width-cornerBoarder, codeRect.origin.y, cornerBoarder, cornerLineWidth)];
    rightUpVerticalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:rightUpVerticalLine];
    
    //右上角 水平线
    UIView *rightUpHorizontalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x+codeRect.size.width-cornerLineWidth, codeRect.origin.y, cornerLineWidth, cornerBoarder)];
    rightUpHorizontalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:rightUpHorizontalLine];
    
    //右下角 垂直线
    UIView *rightDownVerticalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x+codeRect.size.width-cornerBoarder, codeRect.origin.y+codeRect.size.height-cornerLineWidth, cornerBoarder, cornerLineWidth)];
    rightDownVerticalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:rightDownVerticalLine];
    
    //右下角 水平线
    UIView *rightDownHorizontalLine = [[UIView alloc] initWithFrame:CGRectMake(codeRect.origin.x+codeRect.size.width-cornerLineWidth, codeRect.origin.y+codeRect.size.height-cornerBoarder, cornerLineWidth, cornerBoarder)];
    rightDownHorizontalLine.backgroundColor = cornerLineColor;
    [qrCoderView addSubview:rightDownHorizontalLine];
#endif
    
    //---------------------------------------
    
    //添加取景框之外区域，上下左右的半透明效果
    float height = qrCoderView.frame.size.height;
    float width = qrCoderView.frame.size.width;
    
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, codeRect.origin.y)];
    topView.backgroundColor = [UIColor blackColor];
    topView.alpha = 0.5;
    [qrCoderView addSubview:topView];
    
    float y = CGRectGetMaxY(codeRect);
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, height-y)];
    bottomView.backgroundColor = [UIColor blackColor];
    bottomView.alpha = 0.5;
    [qrCoderView addSubview:bottomView];
    
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, codeRect.origin.y, codeRect.origin.x, codeRect.size.height)];
    leftView.backgroundColor = [UIColor blackColor];
    leftView.alpha = 0.5;
    [qrCoderView addSubview:leftView];
    
    float x = CGRectGetMaxX(codeRect);
    UIView *rightView = [[UIView alloc] initWithFrame:CGRectMake(x, codeRect.origin.y, width-x, codeRect.size.height)];
    rightView.backgroundColor = [UIColor blackColor];
    rightView.alpha = 0.5;
    [qrCoderView addSubview:rightView];
    
    //-------------------------------------------------------
}

- (void)setAbstractLabelAttribute
{
    abstractLabel = [[UILabel alloc]init];
    self.abstractLabel.frame = CGRectMake(0, self.codeRect.origin.y+self.codeRect.size.height, CPCAPTURE_BOUND.size.width, 40);
    abstractLabel.textAlignment = NSTextAlignmentCenter;
    abstractLabel.font = [UIFont systemFontOfSize:14];
    abstractLabel.backgroundColor = [UIColor clearColor];
    abstractLabel.textColor = [UIColor whiteColor];
    abstractLabel.text = @"请将扫描框对准二维码，即可自动扫描";
    [self.view addSubview:self.abstractLabel];
}
- (void)setScanLineViewAttribute
{
    scanLineView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"CPQRCode.bundle/images/code_line"]];
    scanLineView.frame = CGRectMake(self.codeRect.origin.x, self.codeRect.origin.y, self.codeRect.size.width, 2);
    [self.view addSubview:scanLineView];
    
    
    //[self animationStart];
    
}
- (void)animationStart
{
    [self animationStop];
    
    self.scanLineAnimation =[CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    self.scanLineAnimation.fromValue = [NSNumber numberWithFloat:0];
    self.scanLineAnimation.toValue= [NSNumber numberWithFloat:self.codeRect.size.height-2];
    self.scanLineAnimation.duration= 3;
    self.scanLineAnimation.repeatCount = 1000;
    self.scanLineAnimation.removedOnCompletion= YES;
    self.scanLineAnimation.fillMode=kCAFillModeForwards;
    [self.scanLineView.layer addAnimation:self.scanLineAnimation forKey:@"transform.translation.y"];
    [self.scanLineView startAnimating];
}
- (void)animationStop
{
    if (self.scanLineAnimation) {
        if (self.scanLineView.isAnimating) {
            [self.scanLineView stopAnimating];
        }
        [self.scanLineView.layer removeAllAnimations];
        
        self.scanLineAnimation = nil;
    }
}
- (void)setCaptureButtonAttribute
{//相册选择 按钮
    captureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    captureButton.frame = CGRectMake(self.view.center.x-17.5, 35, 35, 35);
    [captureButton setImage:[UIImage imageNamed:@"CPQRCode.bundle/images/code_btn"] forState:UIControlStateNormal];
    [captureButton addTarget:self action:@selector(phoneImageButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:captureButton];
}

- (void)setBackButtonAttribute
{
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(20, 35, 35, 35);
//    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton setImage:[UIImage imageNamed:@"CPQRCode.bundle/images/back_info"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(backButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
}

-(void)backButtonAction
{
    [self.captureSession stopRunning];
    self.isScanning = NO;
    
    for(AVCaptureOutput *output in self.captureSession.outputs){
        if([output isMemberOfClass:[AVCaptureVideoDataOutput class]]){
            [(AVCaptureVideoDataOutput*)output setSampleBufferDelegate:nil queue:NULL];
        }
        if([output isMemberOfClass:[AVCaptureMetadataOutput class]]){
            
            [(AVCaptureMetadataOutput*)output setMetadataObjectsDelegate:nil queue:NULL];
        }
        [self.captureSession removeOutput:output];
    }
    
    [self animationStop];
    
//    if(self.presentingViewController){
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }else if(self.navigationController){
//        [self.navigationController popViewControllerAnimated:YES];
//    }
    if(self.presentingViewController){
        [self dismissViewControllerAnimated:YES completion:^{
            if(self.scanResult){
                self.scanResult(@"",NO);
            }
        }];
    }else if(self.navigationController){
        [self.navigationController popViewControllerAnimated:YES];
        if(self.scanResult){
            self.scanResult(@"",NO);
        }
    }
}

//切换开关 -- 开启/关闭闪光灯
-(void)flashLightClick:(UIButton *)button{
    
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if([device isTorchModeSupported:device.torchMode]){
        if (device.torchMode==AVCaptureTorchModeOff) {
            //闪光灯开启
            button.selected = YES;
            [device lockForConfiguration:nil];
            [device setTorchMode:AVCaptureTorchModeOn];
            
        }else if (device.torchMode==AVCaptureTorchModeOn) {
            //闪光灯关闭
            button.selected = NO;
            [device setTorchMode:AVCaptureTorchModeOff];
        }
    }
    
}

//关闭闪光灯
-(void)closeFlashLight
{
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if([device isTorchModeSupported:device.torchMode]){
        if (device.torchMode==AVCaptureTorchModeOn) {
            //闪光灯关闭
            lampButton.selected = NO;
            [device setTorchMode:AVCaptureTorchModeOff];
        }
    }
}

#pragma mark - 打开相册照片选择
//进入相册选择
- (void)phoneImageButton
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    //picker.allowsEditing = NO; //对应使用UIImagePickerControllerOriginalImage获取图片
    picker.allowsEditing = YES; //对应使用UIImagePickerControllerEditedImage获取编辑后图片
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    __weak typeof(self) weakself =self;
    [self presentViewController:picker animated:YES completion:^{
        weakself.isPhoto = YES;
        weakself.isScanning = NO;
        [weakself.captureSession stopRunning];
    }];
    
   
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    //取出选中的原始图片
//    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
//    //大图片压缩过后，识别二维码的速度明显提升了，而且基本上都能识别出来
//    image = [self compressImage:image];
    
    //取出选中的编辑过的图片，如果未编辑，等同OriginalImage
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    
    
    isPhoto = YES;
    
    [self dismissViewControllerAnimated:YES completion:^{
        
        if (CPQR_IOS8) {
            //iOS8以上使用系统自带的CIDetector解码
            [self decodeImageWithCIDetector:image];
            
        }else{
#if (0)
            [self decodeImage:image];  //需要引入ZBar库
#endif
        }
    }];
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    __weak typeof(self) weakSelf =self;
    [self dismissViewControllerAnimated:YES completion:^{
        weakSelf.isPhoto = NO;
        weakSelf.isScanning = YES;
        if (!weakSelf.captureSession.isRunning) {
            [weakSelf.captureSession startRunning];
        }
    }];
}

#pragma mark - 开启相机
- (void)settingSystemCapture
{
     //获取摄像设备,默认是后置相机
    AVCaptureDevice* inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(!inputDevice){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"后置相机不可用。" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    //创建摄像设备的输入流
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"此应用程序没有权限来访问您的相机，您可以在手机“设置->隐私->相机”中启用访问。" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    //初始化Session对象
    self.captureSession = [[AVCaptureSession alloc] init];
    
    [self.captureSession beginConfiguration];
    
    //给Session对象添加输入流
    if ([self.captureSession canAddInput:captureInput]){
        [self.captureSession addInput:captureInput];
    }
    
    
    if (CPQR_IOS7) {
        
        //创建摄像设备的输出流
        AVCaptureMetadataOutput*_output=[[AVCaptureMetadataOutput alloc]init];
        
        //设置代理 在主线程里刷新
        [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        
        //设置一个范围，只处理在这个范围内捕获到的图像信息.它的四个值的范围都是0-1，表示比例。这个Rect里的x对应的恰恰是距离左上角的垂直距离，y对应的是距离左上角的水平距离,宽度和高度设置的情况也是类似。
        [_output setRectOfInterest:CGRectMake(self.codeRect.origin.y/VideoPreviewLayerFrame.size.height,self.codeRect.origin.x/VideoPreviewLayerFrame.size.width,self.codeRect.size.height/VideoPreviewLayerFrame.size.height,self.codeRect.size.width/VideoPreviewLayerFrame.size.width)];

        //高质量采集率
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;//AVCaptureSessionPresetMedium; //High远距离扫描也可识别， Medium需近距离扫描
        
        //给Session对象添加输出流
        if ([self.captureSession canAddOutput:_output]){
            [self.captureSession addOutput:_output];
        }
        
        //设置扫码支持的编码格式(例如二维码,条形码)
        _output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeEAN13Code];

        
        [self.captureSession commitConfiguration];
        
        if (!self.captureVideoPreviewLayer) {
            self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        }
        //设置摄像预览区
        self.captureVideoPreviewLayer.frame = VideoPreviewLayerFrame;
        self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.view.layer addSublayer: self.captureVideoPreviewLayer];
        //[self.view.layer insertSublayer:self.captureVideoPreviewLayer atIndex:0];
    }
#if(0)
    else{ //iOS6及以前，需要借助第3方二维码扫描库，例如ZBar，Zxing
        
        AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        captureOutput.alwaysDiscardsLateVideoFrames = YES;
        
        [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        
        NSString* key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
        NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
        [captureOutput setVideoSettings:videoSettings];
        [self.captureSession addOutput:captureOutput];
        NSString* preset = 0;
        if (NSClassFromString(@"NSOrderedSet") && // Proxy for "is this iOS 5" ...
            [UIScreen mainScreen].scale > 1 &&
            [inputDevice
             supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
                preset = AVCaptureSessionPresetiFrame960x540;
            }
        if (!preset) {
            preset = AVCaptureSessionPresetMedium;
        }
        self.captureSession.sessionPreset = preset;
        
        [self.captureSession commitConfiguration];
        
        if (!self.captureVideoPreviewLayer) {
            self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        }
        self.captureVideoPreviewLayer.frame = VideoPreviewLayerFrame;
        self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.view.layer addSublayer: self.captureVideoPreviewLayer];
        
        
        //设置一个范围，只处理在这个范围内捕获到的图像信息.它的四个值的范围都是0-1，表示比例。这个Rect里的x对应的恰恰是距离左上角的垂直距离，y对应的是距离左上角的水平距离,宽度和高度设置的情况也是类似。
        scropRect = CGRectMake(self.codeRect.origin.y/VideoPreviewLayerFrame.size.height,self.codeRect.origin.x/VideoPreviewLayerFrame.size.width,self.codeRect.size.height/VideoPreviewLayerFrame.size.height,self.codeRect.size.width/VideoPreviewLayerFrame.size.width);

    }
#endif
}

#pragma mark AVCaptureMetadataOutputObjectsDelegate  -- IOS7及以上触发
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
//    WXLogInfo(@"captureOutput:didOutputMetadataObjects:");
    
    if (metadataObjects.count>0)
    {
        //解码成功：摄像头扫描（isPhoto=NO）
        [self.captureSession stopRunning];
        self.isScanning = NO;
        if(isPhoto){
            isPhoto = NO;
        }
        
        if([captureOutput isMemberOfClass:[AVCaptureMetadataOutput class]]){
            
            [(AVCaptureMetadataOutput*)captureOutput setMetadataObjectsDelegate:nil queue:NULL];
        }
        [self.captureSession removeOutput:captureOutput];
        
        
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        
        [self animationStop];
        
#if 0
        //scanResult block函数里边需要根据项目具体情况自行做pop扫码页面处理
        if(self.scanResult){
            self.scanResult(metadataObject.stringValue,YES);
        }
#else
        if(self.presentingViewController){
            [self dismissViewControllerAnimated:YES completion:^{
                if(self.scanResult){
                    self.scanResult(metadataObject.stringValue,YES);
                }
            }];
        }else if(self.navigationController){
            [self.navigationController popViewControllerAnimated:YES];
            if(self.scanResult){
                self.scanResult(metadataObject.stringValue,YES);
            }
        }
#endif
        
    }
    
}

#pragma mark - iOS8+ 系统API 图片二维码识别解码
- (void)decodeImageWithCIDetector:(UIImage *)image
{
    NSString *decodeResult = nil;
    
    if (image && image.CGImage) {
        
        //创建探测器 //CIDetectorTypeQRCode NS_AVAILABLE(8_0)
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh/*CIDetectorAccuracyLow*/}];
        
//        NSData *imageData = UIImagePNGRepresentation(image);
//        CIImage *ciImage = [CIImage imageWithData:imageData];
        CIImage *ciImage = [CIImage imageWithCGImage:image.CGImage];
        
        NSArray *features = [detector featuresInImage:ciImage];
        
        //取出探测到的数据, 如果一张大图片上有多个二维码，能同时识别多个
//        for (CIQRCodeFeature *feature in features) {
//            NSString *scannedResult = feature.messageString;
//            DebugLog(@"result:%@",scannedResult);
//        }
        
        
        //默认一般只处理识别的第1个
        if(features && features.count>0){
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            decodeResult = feature.messageString;
        }
    }
    
    
    //进行后续处理(音效、网址分析、页面跳转等)
//    WXLogInfo(@"decodeResult:%@", decodeResult);
    [self handleImageDecodeResult:decodeResult];
}

- (void)handleImageDecodeResult:(NSString*)result
{//从相册选取二维码图片，解码结果
    //成功与否，依据是result是否为nil。
    //二维码所含字符串result为@“”的情况（即result.length==0），算解码成功
    if (result!=nil) {
        //解码成功： zbar扫描图片（isPhoto=NO）， 或者从相册选取识别图片（isPhoto=YES）
        [self.captureSession stopRunning];
        self.isScanning = NO;
        if(isPhoto){
            isPhoto = NO;
        }
        
        for( AVCaptureOutput *output in self.captureSession.outputs){
            
            if([output isMemberOfClass:[AVCaptureVideoDataOutput class]]){
                [(AVCaptureVideoDataOutput*)output setSampleBufferDelegate:nil queue:NULL];
            }
            
            [self.captureSession removeOutput:output];
        }
        
        [self animationStop];
        
#if 0
        //scanResult block函数里边需要根据项目具体情况自行做pop扫码页面处理
        if(self.scanResult){
            self.scanResult(result,YES);
        }
#else
        if(self.presentingViewController){
            [self dismissViewControllerAnimated:YES completion:^{
                if(self.scanResult){
                    self.scanResult(result,YES);
                }
            }];
        }else if(self.navigationController){
            [self.navigationController popViewControllerAnimated:YES];
            if(self.scanResult){
                self.scanResult(result,YES);
            }
        }
#endif
        
    }else{
        //解码失败
        
        if(isPhoto){
            //从相册选取识别图片，解码失败
//            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"从相册选取图片，识别失败！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
//            [alert show];
            
            //此时，不pop扫码页面，还可继续停留在扫码页面，且要恢复扫码状态
            isPhoto = NO;
            self.isScanning = YES;
            if (!captureSession.isRunning) {
                [self.captureSession startRunning];
            }
        }
        
    }
}

#pragma mark -
#pragma mark 需要引入ZBar库 =========== start ============
#if (0) //需要引入ZBar库

#pragma mark Zbar 对图像进行解码
- (void)decodeImage:(UIImage *)image
{
    ZBarReaderController* read = [[ZBarReaderController alloc]init];
    if (!isPhoto) {
        read.scanCrop = scropRect;
    }
    CGImageRef cgImageRef = image.CGImage;
    read.showsHelpOnFail = NO;
    ZBarImageScanner *scanner = read.scanner;
    [scanner setSymbology:ZBAR_I25 config:ZBAR_CFG_ENABLE to:0];
    
    id <NSFastEnumeration> result = [read scanImage:cgImageRef];
    ZBarSymbol *symbol = nil;
    for(symbol in result)
    {
      break; //此时symbol已经被赋值第0个元素的值后跳出循环
        
    }
    
    [self handleImageDecodeResult:symbol.data];
}


#pragma mark 处理sampleBuffer 并返回 image
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace)
    {
        DebugLog(@"CGColorSpaceCreateDeviceRGB failure");
        return nil;
    }
    
    // Get the base address of the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a Quartz direct-access data provider that uses data we supply
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize,
                                                              NULL);
    // Create a bitmap image from data supplied by our data provider
    CGImageRef cgImage =
    CGImageCreate(width,
                  height,
                  8,
                  32,
                  bytesPerRow,
                  colorSpace,
                  kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                  provider,
                  NULL,
                  true,
                  kCGRenderingIntentDefault);
    
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    //Create and return an image object representing the specified Quartz image
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0); //me add
    
    return image;
}
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
 
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
    [self decodeImage:image];
}

#endif //需要引入ZBar库
#pragma mark 需要引入ZBar库 =========== end ============

#pragma mark - life cycle

- (void)viewDidLoad{
    [super viewDidLoad];
    self.title = @"二维码扫描";
    
    self.edgesForExtendedLayout = UIRectEdgeNone;  //使self.view的子view 从导航栏下方开始布局, 也就是子view原点(0,0)在self.view的左上角，也就是在导航栏下方开始
    
    //内容区背景色
    self.view.backgroundColor = [UIColor whiteColor];
    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
//    WXLogInfo(@"%s, self.view.bounds=%@", __FUNCTION__, NSStringFromCGRect(self.view.bounds));//{{0, 0}, {375, 603}}
    
    if(self.navigationController!=nil){
        self.navigationController.navigationBarHidden = NO;
        [self configNaviLeftBarButtonItem];
        [self configNaviRightBarButtonItem];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(animationStart) name:UIApplicationDidBecomeActiveNotification object:nil];
    self.isScanning = YES;
    if (!captureSession.isRunning) {
        [self.captureSession startRunning];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self animationStart];
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
  
}
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    self.isScanning = NO;
    [self.captureSession stopRunning];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    //离开扫描页面，自动关闭闪光灯
    [self closeFlashLight];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)dealloc
{
//    WXLogInfo(@"%@,  dealloc", [self class]);
    
    //注销通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark -
-(UIStatusBarStyle)preferredStatusBarStyle
{//重写系统方法
    return UIStatusBarStyleLightContent;
}
#pragma mark -
-(void)configNaviLeftBarButtonItem
{
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.backgroundColor = [UIColor clearColor];
    //iOS11以后UIBarButtonItem类会根据内容调整button的frame，规则：button的frame原点由系统设置相应值，但button的size宽度=MAX(初始frame指定宽度,内容实际宽度)值，button的size高度=MAX(初始frame指定高度,内容实际高度)值。且响应点击事件区域iOS11变为button的size区域而不是iOS10之前的一个默认很宽的区域。 所以button需要设定合适的初始size便于iOS11接收点击事件提高点击灵敏度。
    [backButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
    backButton.frame = CGRectMake(0, 0, 45, 44);
#if 0
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, (backButton.frame.size.height-30/2)/2, 18/2, 30/2)];//size比例和原图片成正比才不失真
    imgView.backgroundColor = [UIColor clearColor];
    imgView.image = [UIImage imageNamed:@"CPQRCode.bundle/images/back_button"];
    [backButton addSubview:imgView]; //这样点击按钮图片没有变暗效果
#elif 0
    //原始图片实际尺寸有可能size很大或很小或各iPhone屏幕分辨率共用一张图。这里统一生成自定尺寸的新image。
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, (backButton.frame.size.height-30/2)/2, 18/2, 30/2)];//size比例和原图片成正比才不失真
    imgView.backgroundColor = [UIColor clearColor];
    imgView.image = [UIImage imageNamed:@"CPQRCode.bundle/images/back_button"];
    UIImage *newImage = [Utils getImageWithView:imgView];
    [backButton setImage:newImage forState:UIControlStateNormal];
#else
    [backButton setImage:[UIImage imageNamed:@"CPQRCode.bundle/images/back_button"] forState:UIControlStateNormal];//图片显示原图逻辑尺寸大小
#endif
    [backButton addTarget:self action: @selector(backAction:) forControlEvents: UIControlEventTouchUpInside];
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc]initWithCustomView:backButton];
    self.navigationItem.leftBarButtonItem = leftItem;
}

-(void)configNaviRightBarButtonItem
{
    self.navigationItem.rightBarButtonItem = nil;
}

-(void)backAction:(id)sender{
    [self backButtonAction];
    [self.navigationController popViewControllerAnimated:YES];
}

/*
问题：iOS8苹果提供了CIDetector的接口去识别图片中的二维码,但是如果直接用手机去拍照得到的图片（含二维码）,再从相机选择图片，CIDetector有时识别不了其中二维码。
解决：由于iPhone拍摄的图片尺寸较大，你可以在回调中压缩图片大小，比如500*500，然后就可以识别了。
 */
-(UIImage *)compressImage:(UIImage*)image
{
    UIImage* bigImage = image;
    float actualHeight = bigImage.size.height;
    float actualWidth = bigImage.size.width;
    float newWidth = 0;
    float newHeight = 0;
    if(actualWidth > actualHeight) {
        //宽图
        newHeight = 500.0f;
        newWidth = actualWidth / actualHeight * newHeight;
    }else
    {
        //长图
        newWidth = 500.0f;
        newHeight = actualHeight / actualWidth * newWidth;
    }
    
    CGRect newRect = CGRectMake(0.0, 0.0, newWidth, newHeight);
    
    UIGraphicsBeginImageContext(newRect.size);
    [bigImage drawInRect:newRect];// scales image to rect
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //RETURN
    return theImage;
}
-(CGFloat)screenTopSafeMargin {
    if (IPHONEX) {
        return 44;
    }
    return 0;
}

-(CGFloat)screenBottomSafeMargin {
    if (IPHONEX) {
        return 34;
    }
    return 0;
}

-(CGFloat)statusBarHeight {
    if (IPHONEX) {
        return 44;
    }
    return 20;
}

-(CGFloat)naviBarHeight {
    return 44;
}

-(CGFloat)statusNaviTotalHeight {
    return [self statusBarHeight] + [self naviBarHeight];
}

@end

@implementation CPQRCoderView
@synthesize  captureWidth;
@synthesize cornerBoarder;
@synthesize cornerLineWidth;
@synthesize codeViewRect;
- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
       
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    
    //self.backgroundColor = [UIColor clearColor];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor* checkmarkBlue2 = [UIColor clearColor];//[UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:0.5f];
    
    //// Shadow Declarations
//    UIColor* shadow2 = [UIColor whiteColor];
//    CGSize shadow2Offset = CGSizeMake(-1, 1);
//    CGFloat shadow2BlurRadius = 0.1f;
    
    
    
    //// CheckedOval Drawing 取景框区域
    UIBezierPath* checkedOvalPath = [UIBezierPath bezierPathWithRect: self.codeViewRect];
    CGContextSaveGState(context);
    //CGContextSetShadowWithColor(context, shadow2Offset, shadow2BlurRadius, shadow2.CGColor);
    //将某个颜色设置为填充时要使用的颜色
    [checkmarkBlue2 setFill];
    //使用填充色填充 取景框区域
    [checkedOvalPath fill];
    CGContextRestoreGState(context);
    
    //将某个颜色设置为轮廓线颜色
    [[UIColor whiteColor] setStroke];
    checkedOvalPath.lineWidth = 1;
    //使用轮廓色描绘轮廓线
    [checkedOvalPath stroke];
    
    
#if (1)
    //绘制边角小勾
    
    //设置画笔的颜色（3个1：白色,3个0:黑色）
    CGContextSetStrokeColorWithColor(context, [[UIColor greenColor]CGColor]);
    //设置填充颜色 4个角
    //CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextSetFillColorWithColor(context, [[UIColor clearColor] CGColor]);
    //设置线条宽度
    CGContextSetLineWidth(context, 2.f);
    //设置线条起始端样式的方法
    CGContextSetLineCap(context, kCGLineCapRound);
    //设置线条拐角的样式
    CGContextSetLineJoin(context, kCGLineJoinRound);
    //将画笔移动到某一点
    CGContextMoveToPoint(context, self.codeViewRect.origin.x, self.codeViewRect.origin.y+self.cornerLineWidth);
    //添加线条
    CGContextAddLineToPoint(context, self.codeViewRect.origin.x, self.codeViewRect.origin.y);
    CGContextAddLineToPoint(context,self.codeViewRect.origin.x+self.cornerLineWidth, self.codeViewRect.origin.y);
    
    
    CGContextMoveToPoint(context, self.codeViewRect.origin.x+self.captureWidth-self.cornerLineWidth, self.codeViewRect.origin.y);
    //添加线条
    CGContextAddLineToPoint(context, self.codeViewRect.origin.x+self.captureWidth, self.codeViewRect.origin.y);
    CGContextAddLineToPoint(context,self.codeViewRect.origin.x+self.captureWidth, self.codeViewRect.origin.y+self.cornerLineWidth);

    CGContextMoveToPoint(context, self.codeViewRect.origin.x+self.captureWidth, self.codeViewRect.origin.y+self.captureHeight-self.cornerLineWidth);
    //添加线条
    CGContextAddLineToPoint(context,  self.codeViewRect.origin.x+self.captureWidth, self.codeViewRect.origin.y+self.captureHeight);
    CGContextAddLineToPoint(context, self.codeViewRect.origin.x+self.captureWidth-self.cornerLineWidth, self.codeViewRect.origin.y+self.captureHeight);
    
    CGContextMoveToPoint(context, self.codeViewRect.origin.x+self.cornerLineWidth, self.codeViewRect.origin.y+self.captureHeight);
    //添加线条
    CGContextAddLineToPoint(context, self.codeViewRect.origin.x, self.codeViewRect.origin.y+self.captureHeight);
    CGContextAddLineToPoint(context,self.codeViewRect.origin.x, self.codeViewRect.origin.y+self.captureHeight-self.cornerLineWidth);
    //完成绘制
    CGContextDrawPath(context, kCGPathFillStroke);
#endif
    
}


@end
