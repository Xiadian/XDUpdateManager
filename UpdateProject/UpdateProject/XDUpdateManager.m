//
//  RSUpdateManager.m
//  UpdateProject
//
//  Created by XiaDian on 2017/3/27.
//  Copyright © 2017年 Boreee. All rights reserved.
//

#import "XDUpdateManager.h"
#import <AFNetworking.h>
@interface XDUpdateManager ()
/**
 线上版本
 */
@property(nonatomic,copy)NSString * onlineVersion;
/**
本地版本
 */
@property(nonatomic,copy)NSString * locVersion;
/**
appStoreUrl
 */
@property(nonatomic,copy)NSString * appStoreUrl;
/**
 存更新信息的plist文件路径
 */
@property(nonatomic,copy)NSString * updatePlistPath;

@end
@implementation XDUpdateManager
/**
 构造方法

 @return 返回当前对象类型
 */
- (instancetype)init
{
    self = [super init];
    if (self) {
        //通过plist 文件获取应用当前本地版本
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        self.locVersion= [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        self.appStoreUrl=[[NSString alloc] initWithFormat:@"http://itunes.apple.com/lookup?id=%@",APPID];
        NSArray*paths=NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
        NSString*path=[paths objectAtIndex:0];
        NSString *filePath=[path stringByAppendingPathComponent:@"/update.plist"];
        self.updatePlistPath=filePath;
    }
    return self;
}

/**
 检查更新方法
 */
+(void)CheckVersionUpadateWithForce:(BOOL)isForce{
    XDUpdateManager *manager=[[XDUpdateManager alloc]init];
    [[AFHTTPSessionManager manager]GET:manager.appStoreUrl parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        //判断是否有结果
        if(responseObject[@"resultCount"]>0){
            //取出线上的版本号
            NSString *onlineVersion=[responseObject[@"results"] firstObject][@"version"];
            switch ([manager compareOnlineVersion:onlineVersion toVersion:manager.locVersion]) {
                //线上的版本小  不做操作
                case -1:
                {
                }
                    break;
                //版本相同
                case 0:
                {   //也许是app更新完成后 需要清空之前取消次数
                   [manager clearPlistChannelCount];
                }
                    break;
                //线上的版本大 说明本地要进行更新操作
                case 1:
                {  //是否强制更新
                    if(isForce){
                        [manager showAlert:YES];
                    }
                    //带取消按钮更新弹窗
                    else{
                         [manager showAlert:NO];
                    }
                }
                    break;
                default:
                    break;
            } ;
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        //失败苹果服务器挂了 不做操作
    }];
}

/**
 更新弹窗

 @param isforce 是否为强制弹窗
 */
-(void)showAlert:(BOOL)isforce{
    
    UIAlertController *alertVc=[UIAlertController alertControllerWithTitle:UPDATEMESSEGE message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    UIViewController *cv=[self getCurrentVC];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:UPDATEOK style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        //跳转到appStore 须真机测试看效果
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/cn/app/id%@?mt=8",APPID]] options:@{} completionHandler:nil];
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:UPDATECHANNEL style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        //异步操作吧 文件写入有点费时
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            //增加取消次数
            [self ChannelCountAdd];
        });
    }];

    if (isforce) {
        //添加按钮
        [alertVc addAction:ok];
    
        [cv presentViewController:alertVc animated:YES completion:nil];
    }
    else{
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            //这个需要文件创建读写费时就异步啦
            NSInteger chanelCount=[self getChannelCount];
            dispatch_async(dispatch_get_main_queue(), ^{
                //看是否弹出最大次数 弹出窗体
                if (chanelCount<MAXCHANNELCOUNT) {
                    //添加按钮
                    [alertVc addAction:ok];
                    [alertVc addAction:cancel];
                    [cv presentViewController:alertVc animated:YES completion:nil];
                }
            });
        });
    }
}
/**
 获取当前屏幕显示的viewcontroller

 @return 当前正在显示的viewcontroller
 */
- (UIViewController *)getCurrentVC
{
    UIViewController *result = nil;
    
    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal)
    {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows)
        {
            if (tmpWin.windowLevel == UIWindowLevelNormal)
            {
                window = tmpWin;
                break;
            }
        }
    }
    UIView *frontView = [[window subviews] objectAtIndex:0];
    
    id nextResponder = [frontView nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]])
        result = nextResponder;
    else
        result = window.rootViewController;
    
    return result;
}

/**
 版本更新把取消更新次数置空
 */
-(void)clearPlistChannelCount{
    
    //先判断plist是否存在 不存在可以先不考虑 等有更新在创建文件就可以
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.updatePlistPath]) {
        
        //判断plist文件中存的版本
        
        NSString *plistVersion=[NSDictionary dictionaryWithContentsOfFile:self.updatePlistPath][@"plistVersion"];
        
        //如果plist文件中版本不同则更新plist文件中版本号并清空取消次数
        
        if (![plistVersion isEqualToString:self.locVersion]) {
            
            NSMutableDictionary *updateDic=[NSMutableDictionary dictionaryWithContentsOfFile:self.updatePlistPath];
            
            [updateDic setValue:@(0) forKey:@"channelCount"];
            
            [updateDic setValue:self.locVersion forKey:@"plistVersion"];
            
            [updateDic writeToFile:self.updatePlistPath atomically:YES];
        }
    }
}
/**
 获取到点击取消按钮的次数
 */
-(NSInteger)getChannelCount{
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:_updatePlistPath];
    if (result) {
      NSNumber *count=[NSDictionary dictionaryWithContentsOfFile:_updatePlistPath][@"channelCount"];
        return  [count integerValue];
    }
    else{
        //创建时将本地版本加入plist文件
        NSDictionary *dic=[NSDictionary dictionaryWithObjectsAndKeys:@(0),@"channelCount",self.locVersion,@"plistVersion",nil];
        [dic writeToFile:_updatePlistPath atomically:YES];
        return 0;
    }
    return 0;
}
/**
取消按钮点击记录增加次数
 */
-(void)ChannelCountAdd{
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:_updatePlistPath];
    if (result) {
        NSMutableDictionary *updateDic=[NSMutableDictionary dictionaryWithContentsOfFile:_updatePlistPath];
        NSNumber *channelCount=updateDic[@"channelCount"];
        [updateDic setValue:  @([channelCount integerValue]+1) forKey:@"channelCount"];
        [updateDic writeToFile:_updatePlistPath atomically:YES];
    }
}
/**
 版本比较方法
 
 @param versionOne  线上版本
 @param versionTwo 本地项目版本
 @return 比较结果
 */
- (NSComparisonResult)compareOnlineVersion:(NSString*)versionOne toVersion:(NSString*)versionTwo {
    NSArray* versionOneArr = [versionOne componentsSeparatedByString:@"."];
    NSArray* versionTwoArr = [versionTwo componentsSeparatedByString:@"."];
    NSInteger pos = 0;
    while ([versionOneArr count] > pos || [versionTwoArr count] > pos) {
        NSInteger v1 = [versionOneArr count] > pos ? [[versionOneArr objectAtIndex:pos] integerValue] : 0;
        NSInteger v2 = [versionTwoArr count] > pos ? [[versionTwoArr objectAtIndex:pos] integerValue] : 0;
        if (v1 < v2) {
            //版本2大
            return NSOrderedAscending;
        }
        else if (v1 > v2) {
            //版本1大
            return NSOrderedDescending;
        }
        pos++;
    }
   //版本相同
    return NSOrderedSame;
}

@end
