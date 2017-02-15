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
    
    NSLog(@"%@",[NSObject lj_fileSizeToString:[NSObject lj_getAvailableMemorySize]]);
    NSLog(@"%@",[NSObject lj_getSystemVersion]);
    NSLog(@"%@",[NSObject lj_getDeviceName]);
    NSLog(@"%@",[NSObject lj_getDeviceUUID]);
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
