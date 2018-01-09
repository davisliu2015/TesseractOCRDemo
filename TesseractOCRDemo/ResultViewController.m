//
//  ResultViewController.m
//  TesseractOCRDemo
//
//  Created by davisliu on 2018/1/7.
//  Copyright © 2018年 davisliu. All rights reserved.
//

#import "ResultViewController.h"
#import "Masonry.h"

@interface ResultViewController ()
@property (nonatomic, strong) UILabel *textLAbel;
@end

@implementation ResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    self.navigationItem.title = @"识别结果";
    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    
    
    NSString *str = @"";
    NSInteger count = 0;
    for(int i =0; i < [self.text length]; i++) {
        NSString *temp = [self.text substringWithRange:NSMakeRange(i,1)];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[\u4e00-\u9fa5]" options:NSRegularExpressionCaseInsensitive error:nil];
        NSTextCheckingResult *result = [regex firstMatchInString:temp options:0 range:NSMakeRange(0, [temp length])];
        if (result) {
            str = [str stringByAppendingString:temp];
            count++;
            if(count > 10) {
                str = [str stringByAppendingString:@"\n"];
                count = 0;
            }
        }
    }
    
    self.textLAbel = [UILabel new];
    self.textLAbel.backgroundColor = [UIColor whiteColor];
    self.textLAbel.text = str;
    self.textLAbel.numberOfLines = 0;
    self.textLAbel.textAlignment = NSTextAlignmentCenter;
    self.textLAbel.textColor =[UIColor blackColor];
    self.textLAbel.font = [UIFont systemFontOfSize:24];
    [self.view addSubview:self.textLAbel];
    [self.textLAbel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view.mas_top);
        make.left.mas_equalTo(self.view.mas_left);
        make.right.mas_equalTo(self.view.mas_right);
        make.bottom.mas_equalTo(self.view.mas_bottom);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
