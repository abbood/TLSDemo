//
//  ViewController.m
//  TLSDemo
//
//  Created by Abdullah Bakhach on 5/17/15.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "ViewController.h"
#import "TLSTestClient.h"
#import "TLSTestServer.h"

@interface ViewController ()

- (IBAction)buttonClicked:(id)sender;
@end

@implementation ViewController {
    TLSTestServer* _server;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _server = [[TLSTestServer alloc] initWithPort:7777];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonClicked:(id)sender {
    NSLog(@"Initiating test");

    dispatch_async(dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_DEFAULT), ^{
        [TLSTestClient runTestWithHost:@"localhost" port:7777];
    });
}
@end
