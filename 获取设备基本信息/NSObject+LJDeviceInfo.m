//
//  NSObject+LJDeviceInfo.m
//  指纹Api
//
//  Created by Apple on 2017/2/14.
//  Copyright © 2017年 LJ. All rights reserved.
//

#import "NSObject+LJDeviceInfo.h"
#import <mach/mach.h>
#import <sys/mount.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <sys/ioctl.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <AdSupport/AdSupport.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <objc/runtime.h>


@implementation NSObject (LJDeviceInfo)
#pragma mark - 属性
static void *netChangedBlockKey = "netChangedBlockKey";
- (void)setNetChangedBlock:(LJNetChangedBlock)netChangedBlock{
    objc_setAssociatedObject(self, netChangedBlockKey, netChangedBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (LJNetChangedBlock)netChangedBlock{
    return objc_getAssociatedObject(self, netChangedBlockKey);
}

#pragma mark - 跳转到设置
/** 检查当前网络状态 */
+ (void)lj_checkCurrentNetStatusToSetting{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    if (![[Reachability reachabilityForInternetConnection] isReachable]) {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:[info objectForKey:@"CFBundleDisplayName"] message:@"网络连接异常，请检查您的网络设置及APP网络权限是否开启"  delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }
}

#warning 不能跳转到设置页面
//+ (void)lj_skipToSettingWithUrlString:(NSString *)urlString{
//    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]]) {
//        if ([[[UIDevice currentDevice]systemVersion] doubleValue] > 10.0) {
//            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
//        }else{
//            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
//        }
//    }
//}
#pragma mark - 获取设备的基本信息
/** 当前网络状态 */
+ (LJDeviceNetStateType)lj_currentNetStateType{
    LJDeviceNetStateType state = LJDeviceNetStateTypeUnknow;
    
    if([[Reachability reachabilityForInternetConnection] isReachable]){//有网
        
        if ([[Reachability reachabilityForInternetConnection] isReachableViaWiFi]) {// wifi
            state = LJDeviceNetStateTypeWifi;
        }else if ([[Reachability reachabilityForInternetConnection] isReachableViaWWAN]){// 自带网络
            UIApplication *app = [UIApplication sharedApplication];
            NSArray *children = [[[app valueForKeyPath:@"statusBar"]valueForKeyPath:@"foregroundView"]subviews];
            int netType = 0;
            //获取到网络返回码
            for (id child in children) {
                if ([child isKindOfClass:NSClassFromString(@"UIStatusBarDataNetworkItemView")]) {
                    //获取到状态栏
                    netType = [[child valueForKeyPath:@"dataNetworkType"]intValue];
                    
                    switch (netType) {
                        case 0:
                            state = LJDeviceNetStateTypeNone;
                            break;
                        case 1:
                            state = LJDeviceNetStateType2G;
                            break;
                        case 2:
                            state = LJDeviceNetStateType3G;
                            break;
                        case 3:
                            state = LJDeviceNetStateType4G;
                            break;
                        case 5:
                            state = LJDeviceNetStateTypeWifi;
                            break;
                        default:
                            state = LJDeviceNetStateTypeUnknow;
                            break;
                    }
                }
            }
            
        }else{
            state = LJDeviceNetStateTypeUnknow;
        }
        
    }else{ //没有网络
        state = LJDeviceNetStateTypeNone;
    }
    return state;
}
/** 监听网络状态的变换 */
- (void)lj_startNotifiNetStateChanged:(LJNetChangedBlock)netChanged{
    self.netChangedBlock = netChanged;
    // 监听网络状态改变的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStateChange) name:kReachabilityChangedNotification object:nil];
    // 创建Reachability
    // 开始监控网络(一旦网络状态发生改变, 就会发出通知kReachabilityChangedNotification)
    [[Reachability reachabilityForInternetConnection] startNotifier];
    
}
- (void)lj_stopNotifiNetStateChanged{
    [[Reachability reachabilityForInternetConnection] stopNotifier];
}
- (void)networkStateChange{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LJDeviceNetStateType state = [NSObject lj_currentNetStateType];
        if (self.netChangedBlock) {
            self.netChangedBlock(state);
        }
    });
    
}

/** 获取app版本号 */
+ (NSString *)lj_getAppVersion{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

/** 获取设备的UUID */
+ (NSString *)lj_getDeviceUUID{
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

/** 获取当前设备电池等级 */
+ (CGFloat)lj_getBatteryQuantity{
    return [[UIDevice currentDevice] batteryLevel];
}

/** 获取总内存大小 */
+ (long long)lj_getTotalMemorySize{
    return [NSProcessInfo processInfo].physicalMemory;
}

/** 获取当前可用内存 */
+ (long long)lj_getAvailableMemorySize{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmStats, &infoCount);
    if (kernReturn != KERN_SUCCESS)
    {
        return NSNotFound;
    }
    return ((vm_page_size * vmStats.free_count + vm_page_size * vmStats.inactive_count));
}

/** 获取总磁盘容量 */
+ (long long)lj_getTotalDiskSize{
    struct statfs buf;
    unsigned long long freeSpace = -1;
    if (statfs("/var", &buf) >= 0)
    {
        freeSpace = (unsigned long long)(buf.f_bsize * buf.f_blocks);
    }
    return freeSpace;
}

/** 获取可用磁盘容量 */
+ (long long)lj_getAvailableDiskSize{
    struct statfs buf;
    unsigned long long freeSpace = -1;
    if (statfs("/var", &buf) >= 0)
    {
        freeSpace = (unsigned long long)(buf.f_bsize * buf.f_bavail);
    }
    return freeSpace;
}

/** 大小转换 */
+ (NSString *)lj_fileSizeToString:(unsigned long long)fileSize
{
    // 计算苹果手机内部内存，使用1000的数量级，因为苹果使用的是1000，而不是1024.
    NSInteger KB = 1000;
    NSInteger MB = KB*KB;
    NSInteger GB = MB*KB;
    
    if (fileSize < 10)
    {
        return @"0 B";
        
    }else if (fileSize < KB)
    {
        return @"< 1 KB";
        
    }else if (fileSize < MB)
    {
        return [NSString stringWithFormat:@"%.2f KB",((CGFloat)fileSize)/KB];
        
    }else if (fileSize < GB)
    {
        return [NSString stringWithFormat:@"%.2f MB",((CGFloat)fileSize)/MB];
        
    }else
    {
        return [NSString stringWithFormat:@"%.2f GB",((CGFloat)fileSize)/GB];
    }
}
/* 获取设备型号然后手动转化为对应名称 */
+ (NSString *)lj_getDeviceName{
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    NSString*platform = [NSString stringWithCString: systemInfo.machine encoding:NSASCIIStringEncoding];
    
    if([platform isEqualToString:@"iPhone1,1"])  return@"iPhone 2G";
    
    if([platform isEqualToString:@"iPhone1,2"])  return@"iPhone 3G";
    
    if([platform isEqualToString:@"iPhone2,1"])  return@"iPhone 3GS";
    
    if([platform isEqualToString:@"iPhone3,1"])  return@"iPhone 4";
    
    if([platform isEqualToString:@"iPhone3,2"])  return@"iPhone 4";
    
    if([platform isEqualToString:@"iPhone3,3"])  return@"iPhone 4";
    
    if([platform isEqualToString:@"iPhone4,1"])  return@"iPhone 4S";
    
    if([platform isEqualToString:@"iPhone5,1"])  return@"iPhone 5";
    
    if([platform isEqualToString:@"iPhone5,2"])  return@"iPhone 5";
    
    if([platform isEqualToString:@"iPhone5,3"])  return@"iPhone 5c";
    
    if([platform isEqualToString:@"iPhone5,4"])  return@"iPhone 5c";
    
    if([platform isEqualToString:@"iPhone6,1"])  return@"iPhone 5s";
    
    if([platform isEqualToString:@"iPhone6,2"])  return@"iPhone 5s";
    
    if([platform isEqualToString:@"iPhone7,1"])  return@"iPhone 6 Plus";
    
    if([platform isEqualToString:@"iPhone7,2"])  return@"iPhone 6";
    
    if([platform isEqualToString:@"iPhone8,1"])  return@"iPhone 6s";
    
    if([platform isEqualToString:@"iPhone8,2"])  return@"iPhone 6s Plus";
    
    if([platform isEqualToString:@"iPhone8,4"])  return@"iPhone SE";
    
    if([platform isEqualToString:@"iPhone9,1"])  return@"iPhone 7";
    
    if([platform isEqualToString:@"iPhone9,3"])  return@"iPhone 7";
    
    if([platform isEqualToString:@"iPhone9,2"])  return@"iPhone 7 Plus";
    
    if([platform isEqualToString:@"iPhone9,4"])  return@"iPhone 7 Plus";
    
    if([platform isEqualToString:@"iPhone10,1"]) return@"iPhone 8";
    
    if([platform isEqualToString:@"iPhone10,4"]) return@"iPhone 8";
    
    if([platform isEqualToString:@"iPhone10,2"]) return@"iPhone 8 Plus";
    
    if([platform isEqualToString:@"iPhone10,5"]) return@"iPhone 8 Plus";
    
    if([platform isEqualToString:@"iPhone10,3"]) return@"iPhone X";
    
    if([platform isEqualToString:@"iPhone10,6"]) return@"iPhone X";
    
    if([platform isEqualToString:@"iPod1,1"])  return@"iPod Touch 1G";
    
    if([platform isEqualToString:@"iPod2,1"])  return@"iPod Touch 2G";
    
    if([platform isEqualToString:@"iPod3,1"])  return@"iPod Touch 3G";
    
    if([platform isEqualToString:@"iPod4,1"])  return@"iPod Touch 4G";
    
    if([platform isEqualToString:@"iPod5,1"])  return@"iPod Touch 5G";
    
    if([platform isEqualToString:@"iPad1,1"])  return@"iPad 1G";
    
    if([platform isEqualToString:@"iPad2,1"])  return@"iPad 2";
    
    if([platform isEqualToString:@"iPad2,2"])  return@"iPad 2";
    
    if([platform isEqualToString:@"iPad2,3"])  return@"iPad 2";
    
    if([platform isEqualToString:@"iPad2,4"])  return@"iPad 2";
    
    if([platform isEqualToString:@"iPad2,5"])  return@"iPad Mini 1G";
    
    if([platform isEqualToString:@"iPad2,6"])  return@"iPad Mini 1G";
    
    if([platform isEqualToString:@"iPad2,7"])  return@"iPad Mini 1G";
    
    if([platform isEqualToString:@"iPad3,1"])  return@"iPad 3";
    
    if([platform isEqualToString:@"iPad3,2"])  return@"iPad 3";
    
    if([platform isEqualToString:@"iPad3,3"])  return@"iPad 3";
    
    if([platform isEqualToString:@"iPad3,4"])  return@"iPad 4";
    
    if([platform isEqualToString:@"iPad3,5"])  return@"iPad 4";
    
    if([platform isEqualToString:@"iPad3,6"])  return@"iPad 4";
    
    if([platform isEqualToString:@"iPad4,1"])  return@"iPad Air";
    
    if([platform isEqualToString:@"iPad4,2"])  return@"iPad Air";
    
    if([platform isEqualToString:@"iPad4,3"])  return@"iPad Air";
    
    if([platform isEqualToString:@"iPad4,4"])  return@"iPad Mini 2G";
    
    if([platform isEqualToString:@"iPad4,5"])  return@"iPad Mini 2G";
    
    if([platform isEqualToString:@"iPad4,6"])  return@"iPad Mini 2G";
    
    if([platform isEqualToString:@"iPad4,7"])  return@"iPad Mini 3";
    
    if([platform isEqualToString:@"iPad4,8"])  return@"iPad Mini 3";
    
    if([platform isEqualToString:@"iPad4,9"])  return@"iPad Mini 3";
    
    if([platform isEqualToString:@"iPad5,1"])  return@"iPad Mini 4";
    
    if([platform isEqualToString:@"iPad5,2"])  return@"iPad Mini 4";
    
    if([platform isEqualToString:@"iPad5,3"])  return@"iPad Air 2";
    
    if([platform isEqualToString:@"iPad5,4"])  return@"iPad Air 2";
    
    if([platform isEqualToString:@"iPad6,3"])  return@"iPad Pro 9.7";
    
    if([platform isEqualToString:@"iPad6,4"])  return@"iPad Pro 9.7";
    
    if([platform isEqualToString:@"iPad6,7"])  return@"iPad Pro 12.9";
    
    if([platform isEqualToString:@"iPad6,8"])  return@"iPad Pro 12.9";
    
    if([platform isEqualToString:@"i386"])  return@"iPhone Simulator";
    
    if([platform isEqualToString:@"x86_64"])  return@"iPhone Simulator";
    
    return platform;
}

/** 获取手机名称 */
+ (NSString *)lj_getIphoneName{
    return [UIDevice currentDevice].name;
}

/** 获取当前系统名称 */
+ (NSString *)lj_getSystemName{
    return [UIDevice currentDevice].systemName;
}

/** 获取localizedModel */
+ (NSString *)lj_getLocalizedMode{
    return [UIDevice currentDevice].localizedModel;
}

/** 获取当前系统版本号 */
+ (NSString *)lj_getSystemVersion{
    return [UIDevice currentDevice].systemVersion;
}

/** 获取device_model 
    e.g "iPhone7,1"
 */
+ (NSString *)lj_getDeviceModel{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *device_model = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    return device_model;
}

/** 获取mac地址 */
+ (NSString *)lj_getMacAddress{
    if([[Reachability reachabilityForInternetConnection] isReachable]){
        if ([[Reachability reachabilityForInternetConnection] isReachableViaWiFi]) {
            
            NSArray *ifs = CFBridgingRelease(CNCopySupportedInterfaces());
            id info = nil;
            for (NSString *ifnam in ifs) {
                info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((CFStringRef)ifnam);
                if (info && [info count]) {
                    break;
                }
            }
            NSDictionary *dic = (NSDictionary *)info;
            NSString *ssid = [[dic objectForKey:@"SSID"] lowercaseString];
            NSString *bssid = [[dic objectForKey:@"BSSID"] lowercaseString];
            NSLog(@"wifi名称：%@--mac地址：%@",ssid,bssid);
            return bssid;
        }else{
            int mib[6];
            size_t len;
            char *buf;
            unsigned char *ptr;
            struct if_msghdr *ifm;
            struct sockaddr_dl *sdl;
            
            mib[0] = CTL_NET;
            mib[1] = AF_ROUTE;
            mib[2] = 0;
            mib[3] = AF_LINK;
            mib[4] = NET_RT_IFLIST;
            
            if ((mib[5] = if_nametoindex("en0")) == 0) {
                printf("Error: if_nametoindex error/n");
                return NULL;
            }
            
            if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
                printf("Error: sysctl, take 1/n");
                return NULL;
            }
            
            if ((buf = malloc(len)) == NULL) {
                printf("Could not allocate memory. error!/n");
                return NULL;
            }
            
            if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
                printf("Error: sysctl, take 2");
                return NULL;
            }
            
            ifm = (struct if_msghdr *)buf;
            sdl = (struct sockaddr_dl *)(ifm + 1);
            ptr = (unsigned char *)LLADDR(sdl);
            
            NSString *outstring = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
            free(buf);
            
            return [outstring uppercaseString];
        }
    }else{
        return @"";
    }
}

/** 获取mac地址及wifi名称 */
+ (NSString *)macID_Or_wifiName_WhenWifiState:(BOOL)isMacID{
    NSArray *ifs = CFBridgingRelease(CNCopySupportedInterfaces());
    id info = nil;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((CFStringRef)ifnam);
        if (info && [info count]) {
            break;
        }
    }
    NSDictionary *dic = (NSDictionary *)info;
    NSString *ssid = [[dic objectForKey:@"SSID"] lowercaseString];
    NSString *bssid = [[dic objectForKey:@"BSSID"] lowercaseString];
    
    NSLog(@"%@-%@--%@",dic,ssid,bssid);
    if (isMacID) {
        return bssid;
    }else{
        return ssid;
    }
}

/** 获取IP地址 */
+ (NSString *)lj_getDeviceIPAddresses{
    
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    
    NSMutableArray *ips = [NSMutableArray array];
    
    int BUFFERSIZE = 4096;
    
    struct ifconf ifc;
    
    char buffer[BUFFERSIZE], *ptr, lastname[IFNAMSIZ], *cptr;
    
    struct ifreq *ifr, ifrcopy;
    
    ifc.ifc_len = BUFFERSIZE;
    ifc.ifc_buf = buffer;
    
    if (ioctl(sockfd, SIOCGIFCONF, &ifc) >= 0){
        
        for (ptr = buffer; ptr < buffer + ifc.ifc_len; ){
            
            ifr = (struct ifreq *)ptr;
            int len = sizeof(struct sockaddr);
            
            if (ifr->ifr_addr.sa_len > len) {
                len = ifr->ifr_addr.sa_len;
            }
            
            ptr += sizeof(ifr->ifr_name) + len;
            if (ifr->ifr_addr.sa_family != AF_INET) continue;
            if ((cptr = (char *)strchr(ifr->ifr_name, ':')) != NULL) *cptr = 0;
            if (strncmp(lastname, ifr->ifr_name, IFNAMSIZ) == 0) continue;
            
            memcpy(lastname, ifr->ifr_name, IFNAMSIZ);
            ifrcopy = *ifr;
            ioctl(sockfd, SIOCGIFFLAGS, &ifrcopy);
            
            if ((ifrcopy.ifr_flags & IFF_UP) == 0) continue;
            
            NSString *ip = [NSString  stringWithFormat:@"%s", inet_ntoa(((struct sockaddr_in *)&ifr->ifr_addr)->sin_addr)];
            [ips addObject:ip];
        }
    }
    
    close(sockfd);
    NSString *deviceIP = @"";
    
    for (int i=0; i < ips.count; i++) {
        if (ips.count > 0) {
            deviceIP = [NSString stringWithFormat:@"%@",ips.lastObject];
        }
    }
    return deviceIP;
}

/** 获取广告位标识符 */
+ (NSString *)lj_getAdvertisingID{
    return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}

/** 用来辨别设备所使用网络的运营商 */
- (NSString*)lj_checkCarrier{
    NSString *ret = [[NSString alloc]init];
    
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    
    CTCarrier *carrier = [info subscriberCellularProvider];
    
    if (carrier == nil) {
        return @"0";
    }
    
    NSString *code = [carrier mobileNetworkCode];
    if ([code  isEqual: @""]) {
        return @"0";
    }
    if ([code isEqualToString:@"00"] || [code isEqualToString:@"02"] || [code isEqualToString:@"07"]) {
        ret = @"移动";
    }
    if ([code isEqualToString:@"01"]|| [code isEqualToString:@"06"] ) {
        ret = @"联通";
    }
    if ([code isEqualToString:@"03"]|| [code isEqualToString:@"05"] ) {
        ret = @"电信";;
    }
    
    return ret;
}
@end
