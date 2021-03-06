/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 5.x Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define COOKBOOK_PURPLE_COLOR    [UIColor colorWithRed:0.20392f green:0.19607f blue:0.61176f alpha:1.0f]
#define BARBUTTON(TITLE, SELECTOR)     [[UIBarButtonItem alloc] initWithTitle:TITLE style:UIBarButtonItemStylePlain target:self action:SELECTOR]
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

#define VALUE(_INDEX_) [NSValue valueWithCGPoint:points[_INDEX_]]
#define POINT(_INDEX_) [(NSValue *)[points objectAtIndex:_INDEX_] CGPointValue]

// 從貝茲路徑裡取得點座標
void getPointsFromBezier(void *info, const CGPathElement *element) 
{
    NSMutableArray *bezierPoints = (__bridge NSMutableArray *)info;    
    
    // 取得路徑元素型別與其上的點
    CGPathElementType type = element->type;
    CGPoint *points = element->points;
    
    // 如果可用的話（根據型別），把點加入
    if (type != kCGPathElementCloseSubpath)
    {
        [bezierPoints addObject:VALUE(0)];
        if ((type != kCGPathElementAddLineToPoint) &&
            (type != kCGPathElementMoveToPoint))
            [bezierPoints addObject:VALUE(1)];
    }    
    if (type == kCGPathElementAddCurveToPoint)
        [bezierPoints addObject:VALUE(2)];
}

NSArray *pointsFromBezierPath(UIBezierPath *bpath)
{
    NSMutableArray *points = [NSMutableArray array];
    CGPathApply(bpath.CGPath, (__bridge void *)points, getPointsFromBezier);
    return points;
}

UIBezierPath *smoothedPath(UIBezierPath *bpath, int granularity)
{
    NSArray *points = pointsFromBezierPath(bpath);
    
    if (points.count < 4) return bpath;
    
    UIBezierPath *smoothedPath = [UIBezierPath bezierPath];  
    
    // 這裡只拷貝lineWidth，你或許想要拷貝其他東西
    smoothedPath.lineWidth = bpath.lineWidth;

    // 畫出前三點（0..2）
    [smoothedPath moveToPoint:POINT(0)];
    for (int index = 1; index < 3; index++)
        [smoothedPath addLineToPoint:POINT(index)];
    
    // 在p1與p2裡插入點，
    // 從2..3開始
    for (int index = 4; index < points.count; index++)
    {
        CGPoint p0 = POINT(index - 3);
        CGPoint p1 = POINT(index - 2);
        CGPoint p2 = POINT(index - 1);
        CGPoint p3 = POINT(index);
        
        // 使用Catmull-Rom塞縫曲線
        // 從p1 + dx/dy開始加入點，直到p2
        for (int i = 1; i < granularity; i++)
        {
            float t = (float) i * (1.0f / (float) granularity);
            float tt = t * t;
            float ttt = tt * t;
            
            CGPoint pi; // 中間點
            pi.x = 0.5 * (2*p1.x+(p2.x-p0.x)*t + (2*p0.x-5*p1.x+4*p2.x-p3.x)*tt + (3*p1.x-p0.x-3*p2.x+p3.x)*ttt);
            pi.y = 0.5 * (2*p1.y+(p2.y-p0.y)*t + (2*p0.y-5*p1.y+4*p2.y-p3.y)*tt + (3*p1.y-p0.y-3*p2.y+p3.y)*ttt);
            [smoothedPath addLineToPoint:pi];
        }
        
        // 這裡加入p2
        [smoothedPath addLineToPoint:p2];
    }
    
    // 加入最後一點，結束
    [smoothedPath addLineToPoint:POINT(points.count - 1)];
    
    return smoothedPath;
}

@interface TouchTrackerView : UIView
{
    UIBezierPath *path;
    uint granularity;
}
@end

@implementation TouchTrackerView
- (void) didSetGranularity: (UISegmentedControl *) seg
{
    granularity = seg.selectedSegmentIndex;
    [self setNeedsDisplay];
}

- (void) touchesBegan:(NSSet *) touches withEvent:(UIEvent *) event
{
    path = [UIBezierPath bezierPath];    
    path.lineWidth = 4.0f;
    
    UITouch *touch = [touches anyObject];
    [path moveToPoint:[touch locationInView:self]];
}

- (void) touchesMoved:(NSSet *) touches withEvent:(UIEvent *) event
{
    UITouch *touch = [touches anyObject];
    [path addLineToPoint:[touch locationInView:self]];
    [self setNeedsDisplay];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [path addLineToPoint:[touch locationInView:self]];
    [self setNeedsDisplay];
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (void) drawRect:(CGRect)rect
{
    [COOKBOOK_PURPLE_COLOR set];
    [granularity ? smoothedPath(path, granularity + 1) : path stroke];
}

- (id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
        self.multipleTouchEnabled = NO;
    
    return self;
}
@end

@interface TestBedViewController : UIViewController
@end

@implementation TestBedViewController
- (void) loadView
{
    [super loadView];
    self.view = [[TouchTrackerView alloc] initWithFrame:self.view.frame];
    self.view.backgroundColor = [UIColor whiteColor];
       
    // 設定平滑程度
    NSArray *items;
    if (IS_IPHONE) 
        items = [@"Off* 2 * 3 * 4 " componentsSeparatedByString:@"*"];
    else
        items = [@"  Off  *  2   *   3   *   4  " componentsSeparatedByString:@"*"];
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.selectedSegmentIndex = 0;
    [seg addTarget:self.view action:@selector(didSetGranularity:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = seg;   
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
@end

#pragma mark -

#pragma mark Application Setup
@interface TestBedAppDelegate : NSObject <UIApplicationDelegate>
{
    UIWindow *window;
}
@end
@implementation TestBedAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{    
    [application setStatusBarHidden:YES];
    [[UINavigationBar appearance] setTintColor:COOKBOOK_PURPLE_COLOR];
    
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    TestBedViewController *tbvc = [[TestBedViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:tbvc];
    window.rootViewController = nav;
    [window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool {
        int retVal = UIApplicationMain(argc, argv, nil, @"TestBedAppDelegate");
        return retVal;
    }
}