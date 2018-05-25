//
//  TestViewController.m
//  XMPageViewController-master
//
//  Created by 高昇 on 2018/5/23.
//  Copyright © 2018年 xmalt. All rights reserved.
//

#import "TestViewController.h"
#import "TestChildViewController.h"

@interface TestViewController ()<XMPageViewControllerDelegate, XMPageViewControllerDataSource>

@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dataSource = self;
    self.delegate = self;
}

- (NSInteger)numberOfControllersInPageViewController:(XMPageViewController *)pageViewController
{
    return 100;
}

- (UIViewController *)pageViewController:(XMPageViewController *)pageViewController viewControllerForIndex:(NSInteger)index
{
    TestChildViewController *vc = [pageViewController dequeueReusableControllerWithIndex:index];
    if (!vc) {
        vc = [[TestChildViewController alloc] init];
    }
    vc.index = index;
    return vc;
}

@end
