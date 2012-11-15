//
//  MMViewController.m
//  Maps
//
//  Created by Torin on 9/10/12.
//  Copyright (c) 2012 2359 Media Pte Ltd. All rights reserved.
//

#import "MMViewController.h"

#import <Map/RouteMe.h>

#define AUTOMATION_INTERVAL      5
#define MINIMUM_ZOOM_LEVEL       15
#define MAXIMUM_ZOOM_LEVEL       16

#define SINGAPORE_BOUNDS 1
#define SYDNEY_BOUNDS 0

#if SYDNEY_BOUNDS
static RMSphericalTrapezium sydneyBounds = (RMSphericalTrapezium) { (CLLocationCoordinate2D) { -33.996881, 151.069956 }, (CLLocationCoordinate2D) {-33.827068, 151.321268 } };
#elif SINGAPORE_BOUNDS
static RMSphericalTrapezium singaporeBounds = (RMSphericalTrapezium) { (CLLocationCoordinate2D) { 1.240297, 103.63651156 }, (CLLocationCoordinate2D) { 1.46990989, 104.015739 } };
#endif

@interface MMViewController () <RMMapViewDelegate>

@property (nonatomic, weak) IBOutlet RMMapView * mapView;
@property (nonatomic, weak) IBOutlet UILabel * infoLabel;
@property (nonatomic, assign) CLLocationDegrees north;
@property (nonatomic, assign) CLLocationDegrees south;
@property (nonatomic, assign) CLLocationDegrees east;
@property (nonatomic, assign) CLLocationDegrees west;
@property (assign) BOOL crawlingStarted;
@end

@implementation MMViewController

- (void)awakeFromNib {
  [super awakeFromNib];
  
  [RMMapView class];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.mapView.adjustTilesForRetinaDisplay = YES;
  self.mapView.delegate = self;
  
  id<RMTileSource> myTilesource = [[RMMapQuestOSMSource alloc] init];
    //id myTilesource = [[[RMCloudMadeMapSource alloc] initWithAccessKey:@"0199bdee456e59ce950b0156029d6934" styleNumber:999] autorelease];
    //id myTilesource = [[[RMOpenStreetMapSource alloc] init] autorelease];
  [self.mapView setTileSource:myTilesource];
  
  // Constrain view to a bounding box
#if SYDNEY_BOUNDS
  self.north = sydneyBounds.northEast.latitude;
  self.south = sydneyBounds.southWest.latitude;
  self.east = sydneyBounds.northEast.longitude;
  self.west = sydneyBounds.southWest.longitude;
#elif SINGAPORE_BOUNDS
  self.north = singaporeBounds.northEast.latitude;
  self.south = singaporeBounds.southWest.latitude;
  self.east = singaporeBounds.northEast.longitude;
  self.west = singaporeBounds.southWest.longitude;
#endif
  
  self.mapView.minZoom = MINIMUM_ZOOM_LEVEL;
  self.mapView.maxZoom = MAXIMUM_ZOOM_LEVEL;
  
  CLLocationCoordinate2D nw = CLLocationCoordinate2DMake(self.north, self.west);
  [self moveToLatLong:nw];
  
  [self updateInfo];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self updateInfo];
}

- (void)zoomAndSetConstraints
{
  [self.mapView setZoom:MINIMUM_ZOOM_LEVEL];
  
  CLLocationCoordinate2D southWest = CLLocationCoordinate2DMake(self.south, self.west);
  CLLocationCoordinate2D northEast = CLLocationCoordinate2DMake(self.north, self.east);
  [self.mapView setConstraintsSouthWest:southWest northEast:northEast];
}

- (void)startCrawling
{
  if (!self.crawlingStarted) {
    self.crawlingStarted = YES;
  } else
    return;
  
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL crawlingDone = [defaults boolForKey:@"CrawlingDone"];
  if (!crawlingDone) {
    float latestZoomLevel = [defaults floatForKey:@"LatestZoomLevel"];
    if (latestZoomLevel <= MINIMUM_ZOOM_LEVEL) {
      latestZoomLevel = MINIMUM_ZOOM_LEVEL;
    }
    
    [self.mapView setZoom:latestZoomLevel];
    
    //Recursive
    [self performSelector:@selector(moveRightOneStep) withObject:nil afterDelay:AUTOMATION_INTERVAL];
  } else {
    [self zoomAndSetConstraints];
  }
}

- (void)updateInfo
{
  CLLocationCoordinate2D mapCenter = self.mapView.centerCoordinate;
  
  [[NSUserDefaults standardUserDefaults] setFloat:self.mapView.zoom forKey:@"LatestZoomLevel"];
  
	double truescaleDenominator = self.mapView.scaleDenominator;
  double routemeMetersPerPixel = self.mapView.scaledMetersPerPixel;
  NSString *infoString = [NSString stringWithFormat:@"Latitude : %.5f\nLongitude : %.5f\nZoom: %.2f\nMeter per pixel : %.2f\nTrue scale : 1:%.0f",
                          mapCenter.latitude,
                          mapCenter.longitude,
                          self.mapView.zoom,
                          routemeMetersPerPixel,
                          truescaleDenominator];
  
  self.infoLabel.text = infoString;
}


#pragma mark - Helpers

- (void)moveToLatLong:(CLLocationCoordinate2D)latLong
{
  [self.mapView setCenterCoordinate:latLong];
}

- (void)moveRightOneStep
{
  //Down 1 line
  CLLocationCoordinate2D mapCenter = self.mapView.centerCoordinate;
  if (mapCenter.longitude >= self.east) {
    [self resetToWest];
    [self moveDownOneStep];
    [self updateInfo];
    [self performSelector:@selector(moveRightOneStep) withObject:nil afterDelay:AUTOMATION_INTERVAL];
    return;
  }
  
  //Zoom in 1 level and repeat
  if (mapCenter.latitude <= self.south) {
    BOOL done = [self zoomInOneLevel];
    if (done)
      return;
    [self resetToWest];
    [self resetToNorth];
    [self updateInfo];
    [self performSelector:@selector(moveRightOneStep) withObject:nil afterDelay:AUTOMATION_INTERVAL];
    return;
  }
  
  //Move the map
  [self.mapView moveBy:CGSizeMake(self.mapView.bounds.size.width, 0)];
  [self updateInfo];
  
  //Recursive
  [self performSelector:@selector(moveRightOneStep) withObject:nil afterDelay:AUTOMATION_INTERVAL];
}

- (void)moveDownOneStep
{
  [self.mapView moveBy:CGSizeMake(0, self.mapView.bounds.size.height)];
}

- (void)resetToWest
{
  CLLocationCoordinate2D mapCenter = self.mapView.centerCoordinate;
  [self moveToLatLong:CLLocationCoordinate2DMake(mapCenter.latitude, self.west)];
}

- (void)resetToNorth
{
  CLLocationCoordinate2D mapCenter = self.mapView.centerCoordinate;
  [self moveToLatLong:CLLocationCoordinate2DMake(self.north, mapCenter.longitude)];
}

- (BOOL)zoomInOneLevel
{
  //All done
  if (self.mapView.zoom >= MAXIMUM_ZOOM_LEVEL) {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CrawlingDone"];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:@"Done"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles: nil];
    [alert show];
    return YES;
  }
  
  [self.mapView zoomInToNextNativeZoomAt:self.mapView.center animated:YES];
  return NO;
}


#pragma mark - Delegate methods

- (void)afterMapMove:(RMMapView *)map {
  if (floor(map.centerCoordinate.latitude) == floor(self.north) && floor(self.mapView.centerCoordinate.longitude) == floor(self.west))
    [self startCrawling];
  
  [self updateInfo];
}

- (void)afterMapZoom:(RMMapView *)map {
  [self updateInfo];
}

@end
