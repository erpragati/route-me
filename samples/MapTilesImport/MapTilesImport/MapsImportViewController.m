//
//  MapsImportViewController.m
//  MapTilesImport
//
//  Created by Jesse Armand on 7/11/12.
//  Copyright (c) 2012 2359 Media Pte Ltd. All rights reserved.
//

#import "MapsImportViewController.h"

#import <Map/RMMapQuestOSMSource.h>
#import <Map/RMAbstractWebMapSource.h>
#import <Map/RMTileCache.h>
#import <Map/RMDatabaseCache.h>

@interface MapsImportViewController () <UITextFieldDelegate>

@property (strong, nonatomic) RMDatabaseCache *dbCache;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UIButton *importButton;
@property (weak, nonatomic) IBOutlet UITextField *textField;

@property (copy, nonatomic) NSString *cityName;

@end

@implementation MapsImportViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        NSString *dbPath = [RMDatabaseCache dbPathUsingCacheDir:NO];
        self.dbCache = [[RMDatabaseCache alloc] initWithDatabase:dbPath];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.textField.text = @"Singapore";
    self.textField.delegate = self;
    
    [self.importButton addTarget:self action:@selector(startImport:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)startImport:(id)sender
{
    self.cityName = self.textField.text;
    
    if ([self.cityName length] == 0) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Import Failed!"
                                                            message:@"Please Enter a City Name"
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    
    [self.textField resignFirstResponder];
    
    [self.activityIndicatorView startAnimating];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int zoom = 13; zoom < 17; ++zoom)
        {
            [self startImportForZoom:zoom forCity:self.cityName];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicatorView stopAnimating];
        });
    });
}

- (void)startImportForZoom:(int)zoom forCity:(NSString *)city
{
    if ([city length] == 0)
        return;

    NSData *jsonData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MapTilesInfo" ofType:@"json"]];
    NSError *error;
    NSDictionary *mapTilesInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
    NSDictionary *cityMapTiles = [mapTilesInfo objectForKey:city];
    if (error != nil)
        NSLog(@"%@", error);
    
    NSDictionary *tileDict = [cityMapTiles objectForKey:[@(zoom) stringValue]];
    int tileX = [[tileDict objectForKey:@"tileX"] intValue];
    int finalTileX = [[tileDict objectForKey:@"finalTileX"] intValue];
    int tileY = [[tileDict objectForKey:@"tileY"] intValue];
    int finalTileY = [[tileDict objectForKey:@"finalTileY"] intValue];
    
    NSString *tileImagePath;
    RMTile tile = RMTileMake(tileX, tileY, zoom);
    
    for (int x = tileX; x < finalTileX; ++x)
    {
        for (int y = tileY; y < finalTileY; ++y)
        {
            NSString *resourceName = [NSString stringWithFormat:@"%d/%d/%d", zoom, x, y];
            tileImagePath = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:city];
            
            NSLog(@"Importing %@", tileImagePath);
            
            UIImage *tileImage = [UIImage imageWithContentsOfFile:tileImagePath];
            tile = RMTileMake(x, y, zoom);
            [self.dbCache addImage:tileImage forTile:tile withCacheKey:@"MapQuestOSM"];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Text Field

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    self.cityName = textField.text;
    
    [textField resignFirstResponder];
    
    return YES;
}

@end
