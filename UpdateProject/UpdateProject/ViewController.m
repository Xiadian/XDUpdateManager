//
//  ViewController.m
//  UpdateProject
//
//  Created by XiaDian on 2017/3/27.
//  Copyright © 2017年 Boreee. All rights reserved.
//

#import "ViewController.h"
#import "XDUpdateManager.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //最好通过与后台的交互 后台返回该版本是否为强制更新版本 作为判断来确定更新弹窗的弹出种类
}

/**
 强制得点去AppStore

 @param sender sender
 */
- (IBAction)btnClick:(id)sender {
    //若此版本要强制更新的话把本方法写在AppDelegate里
     [XDUpdateManager CheckVersionUpadateWithForce:YES];
}

/**
 非强制去AppStore
 @param sender sender
 */
- (IBAction)btnNotForeClick:(id)sender {
       //若此版本没必要强制更新的话把本方法写在AppDelegate里
         [XDUpdateManager CheckVersionUpadateWithForce:NO];
}

@end
