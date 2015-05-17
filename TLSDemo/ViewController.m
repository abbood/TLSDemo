//
//  ViewController.m
//  TLSDemo
//
//  Created by Abdullah Bakhach on 5/17/15.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

- (IBAction)buttonClicked:(id)sender;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonClicked:(id)sender {
    NSLog(@"i just got clicked!");
}
@end
