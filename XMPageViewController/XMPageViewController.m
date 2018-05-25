//
//  XMPageViewController.m
//  XMPageViewController-master
//
//  Created by 高昇 on 2018/5/23.
//  Copyright © 2018年 xmalt. All rights reserved.
//

#import "XMPageViewController.h"
#import <objc/runtime.h>

/* 属性标识 */
static char kIdentifier;

@interface UIViewController (Identifier)
/* 控制器标识 */
@property(nonatomic, assign)NSInteger identifier;

@end

@implementation UIViewController (Identifier)

- (void)setIdentifier:(NSInteger)identifier
{
    objc_setAssociatedObject(self, &kIdentifier, [NSNumber numberWithInteger:identifier], OBJC_ASSOCIATION_ASSIGN);
}
- (NSInteger)identifier
{
    return [objc_getAssociatedObject(self, &kIdentifier) integerValue];
}

@end

#define kXMWS(weakSelf) __weak __typeof(&*self) weakSelf = self
#define kXMScreenW [[UIScreen mainScreen] bounds].size.width

/* 最大控制器 */
static NSInteger const kMaxCount = 3;
/* 侧边栏占比 */
static CGFloat const kLeftViewScale = 0.95;
static CGFloat const kAnimationTime = 0.25;

/**
 子控制器试图显示状态
 
 - XMPageSubviewsStatusHide: 隐藏无关界面
 - XMPageSubviewsStatusShow: 显示全部子试图
 */
typedef NS_ENUM(NSInteger, XMPageSubviewsStatus) {
    XMPageSubviewsStatusHide,
    XMPageSubviewsStatusShow
};

@interface XMPageViewController ()

/* 总页码 */
@property(nonatomic, assign)NSInteger pageCount;
/* 当前页码 */
@property(nonatomic, assign)NSInteger curPage;
/* 子控制器最大数目 */
@property(nonatomic, assign)NSInteger maxCount;
/* 复用控制器差值 */
@property(nonatomic, assign)NSInteger differIndex;
/* 滑动手势 */
@property(nonatomic, strong)UIPanGestureRecognizer *panGesture;

@end

@implementation XMPageViewController

/* 禁用子控制器自动管理生命周期 */
- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.view.layer.masksToBounds = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.curChildVC) [self.curChildVC beginAppearanceTransition:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.curChildVC) [self.curChildVC endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.curChildVC) [self.curChildVC beginAppearanceTransition:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (self.curChildVC) [self.curChildVC endAppearanceTransition];
}

#pragma mark - 公共方法
/**
 复用标识
 
 @param index 子控制器对应index
 @return 复用的子控制器
 */
- (UIViewController *)dequeueReusableControllerWithIndex:(NSInteger)index
{
    /* 判断复用控制器是否存在 */
    NSInteger reuseIndex = labs(index-self.differIndex+_maxCount)%_maxCount;
    if (reuseIndex<self.childViewControllers.count) return self.childViewControllers[reuseIndex];
    return nil;
}

#pragma mark - setting方法
- (void)setDataSource:(id<XMPageViewControllerDataSource>)dataSource
{
    _dataSource = dataSource;
    [self initPageViewLayout];
}

- (void)initPageViewLayout
{
    /* 刷新数据源个数 */
    [self reloadDataSourceCount];
    if (_pageCount>0) {
        if (_startPage<0) _startPage = 0;
        /* 初始化首页码 */
        _curPage = _startPage<_pageCount?_startPage:_pageCount-1;
        /* 计算控制器复用差值，例如首次加载第三页即startPage=2，初始复用第一个控制器，差值则为2 */
        _differIndex = _curPage%_maxCount;
        /* 异步渲染其他子控制器 */
        [self drawingOtherController];
    }
}

#pragma mark - 刷新数据源数目
- (void)reloadDataSourceCount
{
    if (_dataSource && [_dataSource respondsToSelector:@selector(numberOfControllersInPageViewController:)]) {
        _pageCount = [_dataSource numberOfControllersInPageViewController:self];
    }
    /* 存在页码，判断子控制器最大个数 */
    _maxCount = _pageCount>kMaxCount?kMaxCount:_pageCount;
    if (self.childViewControllers.count>_maxCount) {
        /* 有多余子控制器，删除子控制器并删除其子视图 */
        while (self.childViewControllers.count != _maxCount) {
            UIViewController *vc = [self.childViewControllers firstObject];
            [vc.view removeFromSuperview];
            [vc removeFromParentViewController];
        }
    }
}

/* 渲染 */
- (void)drawingOtherController
{
    /* 渲染当前页码界面 */
    UIViewController *curVC = [self childViewControllerForIndex:_curPage];
    if (curVC) {
        curVC.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        [curVC.view addGestureRecognizer:self.panGesture];
        [self.view addSubview:curVC.view];
        [self.view sendSubviewToBack:curVC.view];
        /* 初始化页面加载完成 */
        if (self.delegate && [self.delegate respondsToSelector:@selector(pageViewController:didFinishAnimating:index:)]) {
            [self.delegate pageViewController:self didFinishAnimating:YES index:_curPage];
        }
    }
    
    /* 渲染下一页或者前前页 */
    UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
    if (nextVC) {
        /* 存在下一页 */
        nextVC.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        nextVC.view.hidden = YES;
        [self.view addSubview:nextVC.view];
        [self.view sendSubviewToBack:nextVC.view];
    }else {
        /* 不存在下一页，渲染前前页 */
        nextVC = [self childViewControllerForIndex:_curPage-2];
        if (nextVC) {
            nextVC.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
            nextVC.view.hidden = YES;
            [self.view addSubview:nextVC.view];
            [self.view sendSubviewToBack:nextVC.view];
        }
    }
    
    /* 异步渲染前一页或者下下页 */
    UIViewController *lastVC = [self childViewControllerForIndex:_curPage-1];
    if (lastVC) {
        /* 存在上一页 */
        lastVC.view.frame = CGRectMake(-CGRectGetWidth(self.view.frame), 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        lastVC.view.hidden = YES;
        [self.view insertSubview:lastVC.view atIndex:self.childViewControllers.count-1];
    }else {
        lastVC = [self childViewControllerForIndex:_curPage+2];
        if (lastVC) {
            /* 存在下下页 */
            lastVC.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
            lastVC.view.hidden = YES;
            [self.view addSubview:lastVC.view];
            [self.view sendSubviewToBack:lastVC.view];
        }
    }
    
    /* 渲染完成，添加滑动手势 */
    [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
}

- (UIViewController *)childViewControllerForIndex:(NSInteger)index
{
    return [self childViewControllerForIndex:index isForceRefresh:NO];
}

- (UIViewController *)childViewControllerForIndex:(NSInteger)index isForceRefresh:(BOOL)isForceRefresh
{
    /* 越界处理 */
    if (index<0 || index>=_pageCount) return nil;
    /* 获取当前复用控制器标识 */
    NSInteger reuseIndex = labs(index-_differIndex+_maxCount)%_maxCount;
    if (reuseIndex<self.childViewControllers.count) {
        /* 存在复用控制器 */
        UIViewController *vc = self.childViewControllers[reuseIndex];
        if (vc.identifier != index || isForceRefresh)
        {
            /* 刷新界面 */
            if ([_dataSource respondsToSelector:@selector(pageViewController:viewControllerForIndex:)])
            {
                vc = [_dataSource pageViewController:self viewControllerForIndex:index];
                vc.identifier = index;
            }
        }
        return vc;
    }else {
        /* 不存在复用控制器 */
        if ([_dataSource respondsToSelector:@selector(pageViewController:viewControllerForIndex:)]) {
            UIViewController *vc = [_dataSource pageViewController:self viewControllerForIndex:index];
            vc.identifier = index;
            [self addChildViewController:vc];
            [self.view addSubview:vc.view];
            [self.view sendSubviewToBack:vc.view];
            return [self childViewControllerForIndex:index];
        }
    }
    return nil;
}

/**
 处理试图显示状态
 
 @param status YES/NO
 */
- (void)handlerSubviewsHiddenStatus:(XMPageSubviewsStatus)status
{
    for (UIViewController *vc in self.childViewControllers) {
        if (status == XMPageSubviewsStatusHide) {
            if (vc.identifier == _curPage && vc.view.hidden) {
                vc.view.hidden = NO;
            }else if (vc.identifier != _curPage && !vc.view.hidden) {
                vc.view.hidden = YES;
            }
        }else {
            if (vc.view.hidden) vc.view.hidden = NO;
        }
    }
    if (status == XMPageSubviewsStatusHide) self.panGesture.enabled = YES;
}

#pragma mark - 滑动手势处理
- (void)handlePan:(UIPanGestureRecognizer *)recognizer
{
    /* 获取手势移动 */
    CGPoint translation = [recognizer translationInView:self.view];
    /* 显示所有视图 */
    [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusShow];
    /* 当前控制器 */
    UIViewController *curVC = self.curChildVC;
    /* 当前页面待移动位置 */
    CGFloat curView_x = recognizer.view.center.x+translation.x;
    if (curView_x>kXMScreenW/2)
    {
        /* 当前页面准备右移 */
        CGFloat oldCurViewCenter_x = recognizer.view.center.x;
        if (oldCurViewCenter_x<kXMScreenW/2)
        {
            /* 从下一页移动过来，处理下一页的生命周期 */
            UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
            if (nextVC) {
                /* 下页将要消失 */
                [nextVC beginAppearanceTransition:NO animated:NO];
                /* 当前页将要出现 */
                [curVC beginAppearanceTransition:YES animated:NO];
                /* 下页已经消失 */
                [nextVC endAppearanceTransition];
                /* 当前页已经出现 */
                [curVC endAppearanceTransition];
            }
        }
        /* 判断是否存在上一页，存在则移动上一页 */
        UIViewController *lastVC = [self childViewControllerForIndex:_curPage-1];
        if (lastVC) {
            /* 存在上一页 */
            UIView *lastView = lastVC.view;
            /* 旧的上页frame */
            CGFloat oldLastViewCenter_x = lastView.center.x;
            /* 新的上页frame */
            CGFloat newLastViewCenter_x = lastView.center.x+translation.x;
            /* 判断位置，控制视图生命周期 */
            if (oldLastViewCenter_x<=-kXMScreenW/2 && newLastViewCenter_x>-kXMScreenW/2)
            {
                /* 当前页将要消失 */
                [curVC beginAppearanceTransition:NO animated:NO];
                /* 上页将要出现 */
                [lastVC beginAppearanceTransition:YES animated:NO];
            }
            /* 固定当前页面不动 */
            recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
            /* 设置上一页的位置，在左侧 */
            lastView.center = CGPointMake(newLastViewCenter_x, recognizer.view.center.y);
            /* 设置上一页的层级，最上层 */
            [self.view insertSubview:lastView atIndex:self.childViewControllers.count-1];
        }else {
            /* 固定当前页面不动 */
            recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
        }
    }
    else
    {
        /* 当前页面准备左移 */
        /* 1、判断是否存在上一页面，上一页面不在最左边，则移动上一页面 */
        UIViewController *lastVC = [self childViewControllerForIndex:_curPage-1];
        if (lastVC) {
            /* 存在上一页面，判断上一页面的位置 */
            UIView *lastView = lastVC.view;
            CGFloat oldLastViewCenter_x = lastView.center.x;
            if (oldLastViewCenter_x>-kXMScreenW/2)
            {
                /* 上一页面不在最左端，移动上一页面 */
                CGFloat newLastViewCenter_x = oldLastViewCenter_x+translation.x;
                if (newLastViewCenter_x<=-kXMScreenW/2)
                {
                    /* 上页将要消失 */
                    [lastVC beginAppearanceTransition:NO animated:NO];
                    /* 当前页面将要出现 */
                    [curVC beginAppearanceTransition:YES animated:NO];
                    /* 上页已经消失 */
                    [lastVC endAppearanceTransition];
                    /* 当前页已经出现 */
                    [curVC endAppearanceTransition];
                }
                /* 设置上一页的位置，在左侧 */
                lastView.center = CGPointMake(newLastViewCenter_x, recognizer.view.center.y);
                /* 设置上一页的层级，最上层 */
                [self.view insertSubview:lastView atIndex:self.childViewControllers.count-1];
                /* 判断是否存在下一页面，存在则移动到当前页面之下 */
                UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
                if (nextVC) {
                    UIView *nextView = nextVC.view;
                    /* 设置下一页的位置，在当前页面下 */
                    nextView.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                    [self.view insertSubview:nextView belowSubview:recognizer.view];
                }
            }
            else
            {
                /* 上一页面在最左端，存在下一页则移动当前页面 */
                UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
                if (nextVC) {
                    /* 存在下一页，设置下一页的固定位置 */
                    UIView *nextView = nextVC.view;
                    /* 设置下一页的位置，在当前页面下 */
                    nextView.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                    [self.view insertSubview:nextView belowSubview:recognizer.view];
                    /* 移动当前页面 */
                    /* 旧的当前视图frame */
                    CGFloat oldCurViewCenter_x = curVC.view.center.x;
                    if (oldCurViewCenter_x>=kXMScreenW/2 && curView_x<kXMScreenW/2)
                    {
                        /* 当前页面将要消失 */
                        [curVC beginAppearanceTransition:NO animated:NO];
                        /* 下一页面将要出现 */
                        [nextVC beginAppearanceTransition:YES animated:NO];
                    }
                    /* 移动当前页面 */
                    recognizer.view.center = CGPointMake(curView_x, recognizer.view.center.y);
                }else {
                    /* 不存在下一页，固定当前页 */
                    recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                }
            }
        }
        else
        {
            /* 不存在上一页面，存在下一页移动当前页面 */
            UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
            if (nextVC) {
                /* 存在下一页，设置下一页的固定位置 */
                UIView *nextView = nextVC.view;
                /* 设置下一页的位置，在当前页面下 */
                nextView.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                [self.view insertSubview:nextView belowSubview:recognizer.view];
                /* 移动当前页面 */
                /* 旧的当前视图frame */
                CGFloat oldCurViewCenter_x = curVC.view.center.x;
                if (oldCurViewCenter_x>=kXMScreenW/2 && curView_x<kXMScreenW/2)
                {
                    /* 当前页面将要消失 */
                    [curVC beginAppearanceTransition:NO animated:NO];
                    /* 下一页面将要出现 */
                    [nextVC beginAppearanceTransition:YES animated:NO];
                }
                /* 移动当前页面 */
                recognizer.view.center = CGPointMake(curView_x, recognizer.view.center.y);
            }else {
                /* 不存在下一页，固定当前页 */
                recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
            }
        }
    }
    /* 滑动结束 */
    if ([recognizer state] == UIGestureRecognizerStateEnded || [recognizer state] == UIGestureRecognizerStateFailed || [recognizer state] == UIGestureRecognizerStateCancelled)
    {
        /* 动画开始，禁用手势 */
        self.panGesture.enabled = NO;
        /* 判断当前位置 */
        if (recognizer.view.center.x<(kXMScreenW/2-(1-kLeftViewScale)*kXMScreenW))
        {
            /* 判断是否存在下一页 */
            UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
            /* 将当前页移动到最左边 */
            [UIView animateWithDuration:kAnimationTime animations:^{
                recognizer.view.center = CGPointMake(-kXMScreenW/2, recognizer.view.center.y);
            } completion:^(BOOL finished) {
                /* 判断是否存在上一页 */
                UIViewController *lastVC = [self childViewControllerForIndex:self.curPage+2];
                if (lastVC) {
                    UIView *lastView = lastVC.view;
                    /* 设置上一页的位置，在左侧 */
                    lastView.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                    /* 设置上一页的层级，最底层 */
                    [self.view sendSubviewToBack:lastView];
                }
                if (nextVC) {
                    UIView *nextView = nextVC.view;
                    [nextView addGestureRecognizer:self.panGesture];
                    /* 当前页已经消失 */
                    [curVC endAppearanceTransition];
                    /* 下页已经出现 */
                    [nextVC endAppearanceTransition];
                }
                self.curPage++;
                /* 处理视图 */
                [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
                /* 成功移动到下一页 */
                if ([self.delegate respondsToSelector:@selector(pageViewController:didFinishAnimating:index:)]) {
                    [self.delegate pageViewController:self didFinishAnimating:YES index:self.curPage];
                }
            }];
        }
        else
        {
            /* 当前页面未移动或者移动距离很小 */
            /* 判断当前界面是否移动 */
            if (recognizer.view.center.x>=kXMScreenW/2)
            {
                /* 当前界面未移动，判断上一界面是否移动 */
                UIViewController *lastVC = [self childViewControllerForIndex:_curPage-1];
                if (lastVC) {
                    /* 存在上一界面 */
                    UIView *lastView = lastVC.view;
                    [self.view insertSubview:lastView atIndex:self.childViewControllers.count-1];
                    if (lastView.center.x>-kXMScreenW/2)
                    {
                        /* 上一界面移动了，判断移动距离 */
                        if (lastView.center.x>(-kXMScreenW/2+(1-kLeftViewScale)*kXMScreenW))
                        {
                            /* 上一界面覆盖当前界面 */
                            [UIView animateWithDuration:kAnimationTime animations:^{
                                lastView.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                            } completion:^(BOOL finished) {
                                /* 下一页放置最左边 */
                                UIViewController *nextVC = [self childViewControllerForIndex:self.curPage-2];
                                if (nextVC) {
                                    UIView *nextView = nextVC.view;
                                    nextView.center = CGPointMake(-kXMScreenW/2, recognizer.view.center.y);
                                    [self.view insertSubview:nextView atIndex:self.childViewControllers.count-1];
                                }
                                [lastView addGestureRecognizer:self.panGesture];
                                self.curPage--;
                                /* 当前页已经消失 */
                                [curVC endAppearanceTransition];
                                /* 上页已经出现 */
                                [lastVC endAppearanceTransition];
                                /* 处理视图 */
                                [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
                                /* 成功移动到上页 */
                                if ([self.delegate respondsToSelector:@selector(pageViewController:didFinishAnimating:index:)]) {
                                    [self.delegate pageViewController:self didFinishAnimating:YES index:self.curPage];
                                }
                            }];
                        }
                        else
                        {
                            /* 上一页还原 */
                            [UIView animateWithDuration:kAnimationTime animations:^{
                                lastView.center = CGPointMake(-kXMScreenW/2, recognizer.view.center.y);
                                recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                            } completion:^(BOOL finished) {
                                /* 上页将要消失 */
                                [lastVC beginAppearanceTransition:NO animated:NO];
                                /* 当前页将要出现 */
                                [curVC beginAppearanceTransition:YES animated:NO];
                                /* 上页已经消失 */
                                [lastVC endAppearanceTransition];
                                /* 当前页已经出现 */
                                [curVC endAppearanceTransition];
                                /* 处理视图 */
                                [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
                            }];
                        }
                    }
                    else
                    {
                        /* 上一页未移动 */
                        /* 处理视图 */
                        [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
                    }
                }
                else
                {
                    /* 不存在上一页 */
                    recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                    /* 处理视图 */
                    [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
                }
            }
            else
            {
                /* 当前页移动了，固定上一页 */
                UIViewController *lastVC = [self childViewControllerForIndex:_curPage-1];
                if (lastVC) {
                    UIView *lastView = lastVC.view;
                    lastView.center = CGPointMake(-kXMScreenW/2, recognizer.view.center.y);
                    [self.view insertSubview:lastView atIndex:self.childViewControllers.count-1];
                }
                UIViewController *nextVC = [self childViewControllerForIndex:_curPage+1];
                /* 当前页还原 */
                [UIView animateWithDuration:kAnimationTime animations:^{
                    recognizer.view.center = CGPointMake(kXMScreenW/2, recognizer.view.center.y);
                } completion:^(BOOL finished) {
                    if (nextVC) {
                        /* 下页将要消失 */
                        [nextVC beginAppearanceTransition:NO animated:NO];
                        /* 当前页将要出现 */
                        [curVC beginAppearanceTransition:YES animated:NO];
                        /* 下页已经消失 */
                        [nextVC endAppearanceTransition];
                        /* 当前页已经出现 */
                        [curVC endAppearanceTransition];
                        /* 处理视图 */
                        [self handlerSubviewsHiddenStatus:XMPageSubviewsStatusHide];
                    }
                }];
            }
        }
    }
    [recognizer setTranslation:CGPointZero inView:self.view];
}

#pragma mark - lazy
- (UIPanGestureRecognizer *)panGesture
{
    if (!_panGesture) {
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGesture.enabled = NO;
    }
    return _panGesture;
}

- (UIViewController *)curChildVC
{
    return [self childViewControllerForIndex:_curPage];
}

- (NSInteger)totalPage
{
    return _pageCount;
}

@end
