//
//  SKCaptureViewController.m
//  SKVideoCapture_ImagePicker
//
//  Created by WangYu on 16/5/4.
//  Copyright © 2016年 com.ACoderBear. All rights reserved.
//

#import "SKCaptureViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>

#define COURSE_PRACTICE_VIDEOS_PATH [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"My_Capture_Videos"]

@interface SKCaptureViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@end

@implementation SKCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"点击拍摄";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *captureBtn = [UIButton new];
    [captureBtn setTitle:@"点击拍摄" forState:UIControlStateNormal];
    [captureBtn setBackgroundColor:[UIColor redColor]];
    captureBtn.frame = CGRectMake(100, 200, self.view.frame.size.width - 200, 50);
    [captureBtn addTarget:self action:@selector(captureVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:captureBtn];
    
    // 创建视频保存目录
    [[NSFileManager defaultManager] createDirectoryAtPath:COURSE_PRACTICE_VIDEOS_PATH
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
}

#pragma mark - 拍摄视频

- (void)captureVideo {
    
    //检查相机模式是否可用
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        
        NSLog(@"无可用摄像头");
        return;
    }
    
    //获得相机模式下支持的媒体类型
    NSArray* availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
    
    BOOL canTakeVideo = NO;
    for (NSString* mediaType in availableMediaTypes) {
        if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
            //支持摄像
            canTakeVideo = YES;
            break;
        }
    }
    
    //检查是否支持摄像
    if (!canTakeVideo) {
        
        NSLog(@"不支持摄像功能");
        
        return;
    }
    
    //创建图像选取控制器
    UIImagePickerController* imagePickerController = [[UIImagePickerController alloc] init];
    //设置图像选取控制器的来源模式为相机模式
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    //设置图像选取控制器的类型为视频
    imagePickerController.mediaTypes = [[NSArray alloc] initWithObjects:(NSString*)kUTTypeMovie, nil];
    //设置摄像图像品质
    imagePickerController.videoQuality = UIImagePickerControllerQualityTypeIFrame960x540;
    //允许用户进行编辑
    imagePickerController.allowsEditing = NO;
    // 最长录制时间10分钟
    imagePickerController.videoMaximumDuration = 300;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate
#pragma mark 压缩导出视频和封面图到指定目录
/**
 *  拍摄完成
 *
 *  @param picker 控制器
 *  @param info   包含拍摄的媒体信息
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    
    // 获取媒体类型
    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    
    // 判断是否是视频
    if (![mediaType isEqualToString:(NSString *)kUTTypeMovie]) return;
    
    // 获取视频文件的url
    NSURL* mediaURL = [info objectForKey:UIImagePickerControllerMediaURL];
    
    NSString *videoName = [NSString stringWithFormat:@"%@.mp4", [self uuidString] ? [self uuidString] : [NSDate date]];
    
    NSURL *saveUrl = [NSURL fileURLWithPath:[COURSE_PRACTICE_VIDEOS_PATH stringByAppendingPathComponent:videoName]];
    
    // 抓取封面图
    UIImage *coverImage = [self thumbnailImageForVideo:mediaURL atTime:5];
    
    NSString *imagePath = [[saveUrl.path stringByDeletingPathExtension] stringByAppendingString:@".png"];
    
    // 压缩导出视频
    NSLog(@"视频处理中...");
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:mediaURL options:nil];
    // 压缩质量
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset
                                                                           presetName:AVAssetExportPresetMediumQuality];
    // 输出目录
    exportSession.outputURL = saveUrl;
    // 压缩格式 .mp4
    exportSession.outputFileType = AVFileTypeMPEG4;
    // 异步处理视频
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
#warning 此处为异步处理，如需弹窗提醒等UI操作，请回到主线程进行
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted: {
                // 存到本地
                BOOL stillImage = [[NSFileManager defaultManager] createFileAtPath:imagePath
                                                                          contents:UIImagePNGRepresentation(coverImage)
                                                                        attributes:nil];
                if (stillImage) {
                    NSLog(@"封面保存到本地成功");
                }
                
                //创建ALAssetsLibrary对象并将视频保存到媒体库
                
                ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
                
                [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:mediaURL completionBlock:^(NSURL *assetURL, NSError *error) {
                    
                    if (!error) {
                        
                        NSLog(@"保存到相册成功");
                        
                    }else {
                        
                        NSLog(@"保存到相册失败:%@", error);
                        
                    }
                    
                }];
                NSLog(@"视频处理成功");
                
                break;
            }
            case AVAssetExportSessionStatusFailed:
                NSLog(@"视频处理失败");
                break;
            default:
                break;
        }
    }];
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

/**
 *  取消拍摄
 */
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 抓取视频截图

/**
 *  抓取视频截图
 *
 *  @param videoURL 视频URL路径
 *  @param time     截图时间位置
 *
 *  @return 截图
 */
- (UIImage *)thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60) actualTime:NULL error:&thumbnailImageGenerationError];
    
    if (!thumbnailImageRef)
        NSLog(@"thumbnailImageGenerationError %@", thumbnailImageGenerationError);
    
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
    
    return thumbnailImage;
}

#pragma mark - 生成视频名

/**
 *  随机生成UUID字符串作为视频名称，避免重复
 */
- (NSString *)uuidString {
    CFUUIDRef uuid_ref = CFUUIDCreate(NULL);
    CFStringRef uuid_string_ref= CFUUIDCreateString(NULL, uuid_ref);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuid_string_ref];
    CFRelease(uuid_ref);
    CFRelease(uuid_string_ref);
    return [uuid lowercaseString];
}

@end
