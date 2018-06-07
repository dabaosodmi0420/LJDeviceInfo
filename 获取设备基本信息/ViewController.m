//
//  ViewController.m
//  获取设备基本信息
//
//  Created by Apple on 2017/2/15.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+LJDeviceInfo.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSLog(@"%lu",(unsigned long)[NSObject lj_currentNetStateType]);
    
    UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(20, 80, 150, 30)];
    [self.view addSubview:label];
    if ([[Reachability reachabilityForInternetConnection] isReachableViaWiFi]) {
        label.text = @"wifi";
    }else if ([[Reachability reachabilityForInternetConnection] isReachableViaWWAN]){
        label.text = @"自带网络";
    }
    
    NSLog(@"%@",[NSObject lj_getDeviceUUID]);
    NSLog(@"%@",[NSObject lj_getDeviceName]);
    NSLog(@"mac--%@",[NSObject lj_getMacAddress]);
    
    [NSObject lj_startNotifiNetStateChanged:^(LJDeviceNetStateType netState) {
        NSLog(@"%ld",netState);
        if (netState == LJDeviceNetStateTypeWifi) {
            label.text = @"wifi";
        }else if(netState == LJDeviceNetStateTypeNone){
            label.text = @"none";
        }else if (netState == LJDeviceNetStateType2G){
            label.text = @"2G";
        }else if (netState == LJDeviceNetStateType3G){
            label.text = @"3G";
        }else if (netState == LJDeviceNetStateType4G){
            label.text = @"4G";
        }else{
            label.text = @"unknow";
        }
        [NSObject lj_checkCurrentNetStatusToSetting];
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
