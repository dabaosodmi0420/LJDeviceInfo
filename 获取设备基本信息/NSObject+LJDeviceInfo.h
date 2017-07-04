//
//  NSObject+LJDeviceInfo.h
//  指纹Api
//
//  Created by Apple on 2017/2/14.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSObject (LJDeviceInfo)
+ (NSString *)macID;
/** 获取app版本号 */
+ (NSString *)lj_getAppVersion;

/** 获取设备的UUID */
+ (NSString *)lj_getDeviceUUID;

/** 获取当前设备电池等级 */
+ (CGFloat)lj_getBatteryQuantity;

/** 获取总内存大小 */
+ (long long)lj_getTotalMemorySize;

/** 获取当前可用内存 */
+ (long long)lj_getAvailableMemorySize;

/** 获取总磁盘容量 */
+ (long long)lj_getTotalDiskSize;

/** 获取可用磁盘容量 */
+ (long long)lj_getAvailableDiskSize;

/** 大小转换 */
+ (NSString *)lj_fileSizeToString:(unsigned long long)fileSize;

/* 获取设备型号然后手动转化为对应名称 */
+ (NSString *)lj_getDeviceName;

/** 获取手机名称 */
+ (NSString *)lj_getIphoneName;

/** 获取当前系统名称 */
+ (NSString *)lj_getSystemName;

/** 获取当前系统版本号 */
+ (NSString *)lj_getSystemVersion;

/** 获取localizedModel */
+ (NSString *)lj_getLocalizedMode;

/** 获取device_model */
+ (NSString *)lj_getDeviceModel;

/** 获取mac地址 */
+ (NSString *)lj_getMacAddress;

/** 获取IP地址 */
+ (NSString *)lj_getDeviceIPAddresses;

/** 获取广告位标识符 */
+ (NSString *)lj_getAdvertisingID;

/** 用来辨别设备所使用网络的运营商 */
- (NSString*)lj_checkCarrier;
@end
