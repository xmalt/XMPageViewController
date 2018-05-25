//
//  XMPageViewController.h
//  XMPageViewController-master
//
//  Created by 高昇 on 2018/5/23.
//  Copyright © 2018年 xmalt. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol XMPageViewControllerDataSource,XMPageViewControllerDelegate;

@interface XMPageViewController : UIViewController

/* 起始页码，从0开始，在数据源设置前初始化可用于首次跳转 */
@property(nonatomic, assign)NSInteger startPage;
/* 当前页码 */
@property(nonatomic, assign, readonly)NSInteger curPage;
/* 总页码 */
@property(nonatomic, assign, readonly)NSInteger totalPage;
/* 当前子控制器 */
@property(nullable, nonatomic, strong, readonly)UIViewController *curChildVC;

/* 数据源 */
@property (nullable, nonatomic, weak)id<XMPageViewControllerDataSource> dataSource;
/* 代理 */
@property (nullable, nonatomic, weak)id<XMPageViewControllerDelegate> delegate;

/**
 复用标识
 
 @param index 子控制器对应index
 @return 复用的子控制器
 */
- (nullable __kindof UIViewController *)dequeueReusableControllerWithIndex:(NSInteger)index;

@end

@protocol XMPageViewControllerDataSource<NSObject>

@required

/**
 子控制器数目
 
 @param pageViewController 当前控制器
 @return NSInteger
 */
- (NSInteger)numberOfControllersInPageViewController:(XMPageViewController * _Nonnull)pageViewController;

/**
 复用子控制器并刷新界面
 
 @param pageViewController 当前控制器
 @param index 当前页码
 @return 当前页码对应子控制器
 */
- (nullable UIViewController *)pageViewController:(XMPageViewController * _Nonnull)pageViewController viewControllerForIndex:(NSInteger)index;

@end

@protocol XMPageViewControllerDelegate<NSObject>

@optional

/**
 当前页面翻页结束
 
 @param pageViewController 当前控制器
 @param finished 动画结束
 @param index 当前页码
 */
- (void)pageViewController:(XMPageViewController * _Nonnull)pageViewController didFinishAnimating:(BOOL)finished index:(NSInteger)index;

@end
