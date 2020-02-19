//
//  CPQRCoderViewController.h
//  CocoaPodDemo
//
//  Created by liurenpeng on 7/29/15.
//  Copyright (c) 2015 刘任朋. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef void(^CPScanResult)(NSString* result,BOOL isSucceed);
@interface CPQRCoderView : UIView;
@property (nonatomic, assign)CGFloat captureWidth;
@property (nonatomic, assign)CGFloat captureHeight;
@property (nonatomic, assign)CGFloat cornerLineWidth;
@property (nonatomic, assign)CGFloat cornerBoarder;
@property (nonatomic, assign)CGRect codeViewRect;


@end
@interface CPQRCoderViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate,AVCaptureMetadataOutputObjectsDelegate>
{
    CPQRCoderView *qrCoderView;
}
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong)CPScanResult scanResult;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, strong)CPQRCoderView *qrCoderView;
@property (nonatomic, strong)UIImageView *scanLineView;
@property (nonatomic, strong)CABasicAnimation *scanLineAnimation;
@property (nonatomic, strong)UIButton *lampButton;
/*!
 * @property
 * @abstract 扫描框View
 * @discussion NULL
 * @result NULL
 */
@property (nonatomic, strong)UIImageView *scanView;
/*!
 * @property
 * @abstract 取景框四个角线的长度
 * @discussion NULL
 * @result NULL
 */
@property (nonatomic, assign)CGFloat cornerLineWidth;
/*!
 * @property
 * @abstract 取景框四个角线的粗细
 * @discussion NULL
 * @result NULL
 */
@property (nonatomic, assign)CGFloat cornerBoarder;
/*!
 * @property
 * @abstract 说明label
 * @discussion NULL
 * @result NULL
 */
@property (nonatomic, strong)UILabel *abstractLabel;
/*!
 * @property
 * @abstract 相册buttton
 * @discussion NULL
 * @result NULL
 */
@property (nonatomic, strong)UIButton *captureButton;
/*!
 * @property
 * @abstract 取景框CGRect
 * @discussion NULL
 * @result NULL
 */
@property (nonatomic, assign)CGRect codeRect;
/*!
 * @method
 * @abstract 初始化方法
 * @param 返回二维码信息
 * @discussion NULL
 * @result NULL
 */
- (id)initWithResult:(CPScanResult)result;

- (BOOL)judgeAVCaptureDevice;
@end
