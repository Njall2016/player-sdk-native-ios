//
//  PlayerViewController.m
//  HelloWorld
//
//  Created by Eliza Sapir on 9/11/13.
//
//

// Copyright (c) 2013 Kaltura, Inc. All rights reserved.
// License: http://corp.kaltura.com/terms-of-use
//

#import "PlayerViewController.h"
#if !(TARGET_IPHONE_SIMULATOR)
    #import "WVSettings.h"
    #import "WViPhoneAPI.h"
#endif

@implementation PlayerViewController {
    // Player Params
    BOOL isSeeking;
    BOOL isFullScreen, isPlaying, isResumePlayer, isPlayCalled;
    CGRect originalViewControllerFrame;
    CGAffineTransform fullScreenPlayerTransform;
    UIDeviceOrientation prevOrientation, deviceOrientation;
    NSString *playerSource;
    NSMutableDictionary *appConfigDict;
    BOOL openFullScreen;
    UIButton *btn;
    BOOL isCloseFullScreenByTap;
    BOOL isJsCallbackReady;
    float prevVolume;
    
    // Chromecast
    ChromecastDeviceController* chromecastDeviceController;
    int _lastKnownPlaybackTime;
    NSString *showChromecastButton;
    
  #if !(TARGET_IPHONE_SIMULATOR)
        // WideVine Params
        BOOL isWideVine, isWideVineReady;
        WVSettings* wvSettings;
    #endif
}

@synthesize webView, player;
@synthesize delegate;

- (void)viewDidLoad {
    NSLog(@"View Did Load Enter");
    
    if (self) {
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(deviceConnected:)
         name:ChromcastDeviceControllerDeviceConnectedNotification
         object:nil];
    }
    
    // Chromecast
    // Initialize the chromecast device controller.
    chromecastDeviceController = [ [ChromecastDeviceController alloc] init ];
    [chromecastDeviceController performScan: YES];
    showChromecastButton = @"false";
    
  #if !(TARGET_IPHONE_SIMULATOR)
        [self initWideVineParams];
    #endif
    [self initPlayerParams];
    
    appConfigDict = [NSDictionary dictionaryWithContentsOfFile: [ [NSBundle mainBundle] pathForResource: @"AppConfigurations" ofType: @"plist"]];
    
    // Observer for pause player notifications
    [ [NSNotificationCenter defaultCenter] addObserver: self
                                              selector: @selector(pause)
                                                  name: @"playerPauseNotification"
                                                object: nil ];
    
    [ [NSNotificationCenter defaultCenter] addObserver: self
                                              selector: @selector(showChromecastButton:)
                                                  name: @"showChromecastButtonNotification"
                                                object: nil ];
    
    [ [NSNotificationCenter defaultCenter] addObserver: self
                                              selector: @selector(hideChromecastButton:)
                                                  name: @"hideChromecastButtonNotification"
                                                object: nil ];

    // Pinch Gesture Recognizer - Player Enter/ Exit FullScreen mode
    UIPinchGestureRecognizer *pinch = [ [UIPinchGestureRecognizer alloc] initWithTarget: self action: @selector(didPinchInOut:) ];
    [self.view addGestureRecognizer:pinch];
    
    [super viewDidLoad];
    
    NSLog(@"View Did Load Exit");
}

#pragma mark State management
- (void)deviceConnected:(NSNotification*)notification {
    if ([[notification name] isEqualToString:ChromcastDeviceControllerDeviceConnectedNotification]) {
        NSLog(@"Device has been Connected!");
        
        //Push Chromecast Segue
        if ( chromecastDeviceController.isConnected ) {
            _lastKnownPlaybackTime = [self.player currentPlaybackTime];
            [self.player stop];
        }
    }
    
    // TODO: change to playerSource
    [chromecastDeviceController loadMedia: [NSURL URLWithString: playerSource] thumbnailURL: nil title:@"" subtitle:@"" mimeType:@"" startTime: player.currentPlaybackTime autoPlay: NO];
}

-(void)viewWillAppear:(BOOL)animated {
    NSLog(@"viewWillAppear Enter");
    
    CGRect playerViewFrame = CGRectMake( 0, 0, self.view.frame.size.width, self.view.frame.size.height );
    
    if ( !isFullScreen && !isResumePlayer ) {
        self.webView = [ [PlayerControlsWebView alloc] initWithFrame: playerViewFrame ];
        [self.webView setPlayerControlsWebViewDelegate: self];
        
        self.player = [ [MPMoviePlayerController alloc] init ];
        self.player.view.frame = playerViewFrame;
        
        // WebView initialize for supporting NativeComponent(html5 player view)
        [ [self.webView scrollView] setScrollEnabled: NO ];
        [ [self.webView scrollView] setBounces: NO ];
        [ [self.webView scrollView] setBouncesZoom: NO ];
        self.webView.opaque = NO;
        self.webView.backgroundColor = [UIColor clearColor];
        
        // Add NativeComponent (html5 player view) webView to player view
        [self.player.view addSubview: self.webView];
        [self.view addSubview: player.view];
        self.player.controlStyle = MPMovieControlStyleNone;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(volumeChanged:)
                                                     name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                   object:nil];
        prevVolume = 0;
        
    }
    
    [super viewWillAppear:NO];
    
    NSLog( @"viewWillAppear Exit" );
}

- (void)viewDidDisappear:(BOOL)animated {
    NSLog( @"viewDidDisappear Enter" );
    
    isResumePlayer = YES;
    
    if ( [ [UIDevice currentDevice] userInterfaceIdiom ] == UIUserInterfaceIdiomPhone ) {
        [chromecastDeviceController performScan: NO];
    }
    
    [super viewDidDisappear:animated];
    
    NSLog( @"viewDidDisappear Exit" );
}

#pragma mark - WebView Methods

- (void)setWebViewURL: (NSString *)iframeUrl {
    NSLog( @"setWebViewURL Enter" );
    
    iframeUrl = [iframeUrl stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    [ self.webView loadRequest: [ NSURLRequest requestWithURL: [NSURL URLWithString: iframeUrl] ] ];
    
    NSLog(@"setWebViewURLExit");
}

- (NSString*)writeJavascript:(NSString*)javascript {
    NSLog(@"writeJavascript: %@", javascript);
    
    return [self.webView stringByEvaluatingJavaScriptFromString: javascript];
}

#pragma mark - Chromecast Methods

-(void)playChromecast {
    NSLog(@"playChromecast Enter");
    
    [chromecastDeviceController pauseCastMedia: NO];
    
    NSLog(@"playChromecast Exit");
}

-(void)pauseChromecast {
    NSLog(@"pauseChromecast Enter");
    
    [chromecastDeviceController pauseCastMedia: YES];
    
    NSLog(@"pauseChromecast Exit");
}

-(void)stopChromecast {
    NSLog(@"stopChromecast Enter");
    
    [chromecastDeviceController stopCastMedia];
    
    NSLog(@"stopChromecast Exit");
}

-(void)volumeUpChromecast {
    NSLog(@"volumeUpChromecast Enter");
    
    [chromecastDeviceController changeVolumeIncrease: YES];
    
    NSLog(@"volumeUpChromecast Exit");
}

-(void)volumeDownChromecast {
    NSLog(@"volumeUpChromecast Enter");
    
    [chromecastDeviceController changeVolumeIncrease: NO];
    
    NSLog(@"volumeUpChromecast Exit");
}

#pragma mark - Player Methods

-(void)initPlayerParams {
    NSLog(@"initPlayerParams Enter");
    
    isFullScreen = NO;
    isPlaying = NO;
    isResumePlayer = NO;
    isPlayCalled = NO;
    isJsCallbackReady = NO;
    
    NSLog(@"initPlayerParams Exit");
}

- (void)notifyJsReady {
    NSLog(@"notifyJsReady Enter");
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 2);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        // do work in the UI thread here
           [self setKDPAttribute: @"chromecast" propertyName: @"visible" value: showChromecastButton];
    });
    
    isJsCallbackReady = YES;
    
    NSLog(@"notifyJsReady Exit");
}

- (void)play {
    NSLog( @"Play Player Enter" );
    
    isPlayCalled = YES;
    
  #if !(TARGET_IPHONE_SIMULATOR)
        if ( isWideVine  && !isWideVineReady ) {
            return;
        }
    #endif
    
    if( !( self.player.playbackState == MPMoviePlaybackStatePlaying ) ) {
        [self.player prepareToPlay];
        [self.player play];
    }
    
    if ( chromecastDeviceController ) {
        [self playChromecast];
    }
    
    NSLog( @"Play Player Exit" );
}

- (void)pause {
    NSLog(@"Pause Player Enter");
    
    isPlayCalled = NO;
    
    [self.player pause];
    
    if ( chromecastDeviceController ) {
        [self pauseChromecast];
    }
    
    NSLog(@"Pause Player Exit");
}

- (void)stop {
    NSLog(@"Stop Player Enter");
    
    [self.player stop];
    isPlaying = NO;
    isPlayCalled = NO;
    
  #if !(TARGET_IPHONE_SIMULATOR)
        // Stop WideVine
        if ( isWideVine ) {
            [wvSettings stopWV];
            isWideVine = NO;
            isWideVineReady = NO;
        }
    #endif
    
    if ( chromecastDeviceController ) {
        [self stopChromecast];
    }
    
    NSLog(@"Stop Player Exit");
}

#pragma mark - Player Layout & Fullscreen Treatment

- (void)updatePlayerLayout {
    NSLog( @"updatePlayerLayout Enter" );
    
    //Update player layout
    NSString *updateLayoutJS = @"document.getElementById( this.id ).doUpdateLayout();";
    [self writeJavascript: updateLayoutJS];
    
    // FullScreen Treatment
    NSDictionary *fullScreenDataDict = [ NSDictionary dictionaryWithObject: [NSNumber numberWithBool: isFullScreen]
                                                                    forKey: @"isFullScreen" ];
    [ [NSNotificationCenter defaultCenter] postNotificationName: @"toggleFullscreenNotification"
                                                         object:self
                                                       userInfo: fullScreenDataDict ];
    
    NSLog( @"updatePlayerLayout Exit" );
}

- (void)setOrientationTransform: (CGFloat) angle{
    NSLog( @"setOrientationTransform Enter" );
    
    if ( isFullScreen ) {
        // Init Transform for Fullscreen
        fullScreenPlayerTransform = CGAffineTransformMakeRotation( ( angle * M_PI ) / 180.0f );
        fullScreenPlayerTransform = CGAffineTransformTranslate( fullScreenPlayerTransform, 0.0, 0.0);
        
        self.view.center = [[UIApplication sharedApplication] delegate].window.center;
        [self.view setTransform: fullScreenPlayerTransform];
        
        // Add Mask Support to WebView & Player
        self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;
    }else{
        [self.view setTransform: CGAffineTransformIdentity];
    }
    
    NSLog( @"setOrientationTransform Exit" );
}

- (void)checkDeviceStatus{
    NSLog( @"checkDeviceStatus Enter" );
    
    deviceOrientation = [[UIDevice currentDevice] orientation];
    
    if ( [self isIpad] || openFullScreen ) {
        if (deviceOrientation == UIDeviceOrientationUnknown) {
            if ( [UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationLandscapeLeft ) {
                [self setOrientationTransform: 90];
            }else if([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationLandscapeRight){
                [self setOrientationTransform: -90];
            }else if([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationPortrait){
                [self setOrientationTransform: 180];
                [self.view setTransform: CGAffineTransformIdentity];
            }else if ([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationPortraitUpsideDown){
                [self setOrientationTransform: -180];
            }
        }else{
            if ( deviceOrientation == UIDeviceOrientationLandscapeLeft ) {
                [self setOrientationTransform: 90];
            }else if(deviceOrientation == UIDeviceOrientationLandscapeRight){
                [self setOrientationTransform: -90];
            }else if(deviceOrientation == UIDeviceOrientationPortrait){
                [self setOrientationTransform: 180];
                [self.view setTransform: CGAffineTransformIdentity];
            }else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown){
                [self setOrientationTransform: -180];
            }
        }
    }else{
        if (deviceOrientation == UIDeviceOrientationUnknown ||
            deviceOrientation == UIDeviceOrientationPortrait ||
            deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
            [self setOrientationTransform: 90];
        }else{
            if ( deviceOrientation == UIDeviceOrientationLandscapeLeft ) {
                [self setOrientationTransform: 90];
            }else if( deviceOrientation == UIDeviceOrientationLandscapeRight ){
                [self setOrientationTransform: -90];
            }
        }
    }
    
    NSLog( @"checkDeviceStatus Exit" );
}

- (void)checkOrientationStatus{
    NSLog( @"checkOrientationStatus Enter" );
    
    isCloseFullScreenByTap = NO;
    
    // Handle rotation issues when player is playing
    if ( isPlaying ) {
        [self closeFullScreen];
        [self openFullScreen: openFullScreen];
        if ( isFullScreen ) {
            [self checkDeviceStatus];
        }
        
        if ( ![self isIpad] && (deviceOrientation == UIDeviceOrientationPortrait || deviceOrientation == UIDeviceOrientationPortraitUpsideDown) ) {
            if ( !openFullScreen ) {
                [self closeFullScreen];
            }
        }
    }else {
        [self closeFullScreen];
    }
    
    NSLog( @"checkOrientationStatus Exit" );
}

- (void)toggleFullscreen{
    NSLog( @"toggleFullscreen Enter" );
    
    isCloseFullScreenByTap = YES;
    
    if ( !isFullScreen ) {
        [self openFullScreen: openFullScreen];
        [self checkDeviceStatus];
    } else{
        [self closeFullScreen];
    }
    
    NSLog( @"toggleFullscreen Exit" );
}

- (void)openFullScreen: (BOOL)openFullscreen{
    NSLog( @"openFullScreen Enter" );
    
    isFullScreen = YES;
   
    CGRect mainFrame;
    openFullScreen = openFullscreen;
    
    if ( [self isIpad] || openFullscreen ) {
        if ( [[UIDevice currentDevice] orientation] == UIDeviceOrientationUnknown ) {
            if (UIDeviceOrientationPortrait == [UIApplication sharedApplication].statusBarOrientation || UIDeviceOrientationPortraitUpsideDown == [UIApplication sharedApplication].statusBarOrientation) {
                mainFrame = CGRectMake( [[UIScreen mainScreen] bounds].origin.x, [[UIScreen mainScreen] bounds].origin.y, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height ) ;
            }else if(UIDeviceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)){
                mainFrame = CGRectMake( [[UIScreen mainScreen] bounds].origin.x, [[UIScreen mainScreen] bounds].origin.y, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width ) ;
            }
        }else{
            if ( UIDeviceOrientationPortrait == [[UIDevice currentDevice] orientation] || UIDeviceOrientationPortraitUpsideDown == [[UIDevice currentDevice] orientation] ) {
                mainFrame = CGRectMake( [[UIScreen mainScreen] bounds].origin.x, [[UIScreen mainScreen] bounds].origin.y, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height ) ;
            }else if(UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])){
                mainFrame = CGRectMake( [[UIScreen mainScreen] bounds].origin.x, [[UIScreen mainScreen] bounds].origin.y, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width ) ;
            }
        }
    }else{
        mainFrame = CGRectMake( [[UIScreen mainScreen] bounds].origin.x, [[UIScreen mainScreen] bounds].origin.y, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width ) ;
    }
    
    [self.view setFrame: mainFrame];
    
    if ( ![self isIOS7] ) {
        [UIApplication sharedApplication].statusBarHidden = YES;
    }
    
    [self.player.view setFrame: CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.webView setFrame: self.player.view.frame];
    [ self.view setTransform: fullScreenPlayerTransform ];
    
    [self triggerEventsJavaScript: @"enterfullscreen" WithValue: nil];
    [self updatePlayerLayout];
    
    NSLog( @"openFullScreen Exit" );
}

- (void)closeFullScreen{
    NSLog( @"closeFullScreen Enter" );
    
    if ( openFullScreen && isCloseFullScreenByTap ) {
        [self stop];
    }
    
    CGRect originalFrame = CGRectMake( 0, 0, originalViewControllerFrame.size.width, originalViewControllerFrame.size.height );
    isFullScreen = NO;
    
    [self.view setTransform: CGAffineTransformIdentity];
    self.view.frame = originalViewControllerFrame;
    self.player.view.frame = originalFrame;
    self.webView.frame = self.player.view.frame;
    
    if ( ![self isIOS7] ) {
       [UIApplication sharedApplication].statusBarHidden = NO;
    }
    
    [self triggerEventsJavaScript:@"exitfullscreen" WithValue:nil];
    
    [self updatePlayerLayout];
    
    NSLog( @"closeFullScreen Exit" );
}

// "pragma clang" is attached to prevent warning from “PerformSelect may cause a leak because its selector is unknown”
- (void)handleHtml5LibCall:(NSString*)functionName callbackId:(int)callbackId args:(NSArray*)args{
    NSLog(@"handleHtml5LibCall Enter");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ( [args count] > 0 ) {
        functionName = [NSString stringWithFormat:@"%@:", functionName];
    }
    [self performSelector:NSSelectorFromString(functionName) withObject:args];
#pragma clang diagnostic pop
    
    NSLog(@"handleHtml5LibCall Exit");
}

- (void)bindPlayerEvents{
    NSLog(@"Binding Events Enter");
    
    NSMutableDictionary *eventsDictionary = [[NSMutableDictionary alloc] init];
    [eventsDictionary setObject: MPMoviePlayerLoadStateDidChangeNotification
                         forKey: @"triggerLoadPlabackEvents:"];
    [eventsDictionary setObject: MPMoviePlayerPlaybackDidFinishNotification
                         forKey: @"triggerFinishPlabackEvents:"];
    [eventsDictionary setObject: MPMoviePlayerPlaybackStateDidChangeNotification
                         forKey: @"triggerMoviePlabackEvents:"];
    [eventsDictionary setObject: MPMoviePlayerTimedMetadataUpdatedNotification
                         forKey: @"metadataUpdate:"];
    [eventsDictionary setObject: MPMovieDurationAvailableNotification
                         forKey: @"onMovieDurationAvailable:"];
    for (id functionName in eventsDictionary){
        id event = [eventsDictionary objectForKey:functionName];
        [ [NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: NSSelectorFromString( functionName )
                                                     name: event
                                                   object: player ];
    }
    
    //  200 milliseconds is .2 seconds
    [NSTimer scheduledTimerWithTimeInterval:.2 target:self selector: @selector( sendCurrentTime: ) userInfo:nil repeats:YES];
    //  every second
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector: @selector( updatePlaybackProgressFromTimer: ) userInfo:nil repeats:YES];
    
    NSLog(@"Binding Events Exit");
}

- (void)showChromecastButton: (NSNotification *)note {
    showChromecastButton = @"true";
    [self setKDPAttribute: @"chromecast" propertyName: @"visible" value: showChromecastButton];
}

- (void)hideChromecastButton: (NSNotification *)note {
    showChromecastButton = @"false";
    [self setKDPAttribute: @"chromecast" propertyName: @"visible" value: showChromecastButton];
}

- (void)setKDPAttribute: (NSString*)pluginName propertyName: (NSString *)propertyName value: (NSString*)value{
    NSString *showChromecastBtnStr = [NSString stringWithFormat: @"NativeBridge.videoPlayer.setKDPAttribute('%@','%@', %@);", pluginName, propertyName, value];
    NSLog( @"%@", showChromecastBtnStr );
    [self.webView stringByEvaluatingJavaScriptFromString: showChromecastBtnStr];
}

- (void)triggerLoadPlabackEvents: (NSNotification *)note {
    NSLog(@"triggerLoadPlabackEvents Enter");
    
    NSString *loadStateName = [[NSString alloc]init];
    
    switch ( player.loadState ) {
        case MPMovieLoadStateUnknown:
            loadStateName = @"MPMovieLoadStateUnknown";
            NSLog(@"MPMovieLoadStateUnknown");
            break;
        case MPMovieLoadStatePlayable:
            loadStateName = @"canplay";
            NSLog(@"MPMovieLoadStatePlayable");
            break;
        case MPMovieLoadStatePlaythroughOK:
            loadStateName = @"MPMovieLoadStatePlaythroughOK";
            NSLog(@"MPMovieLoadStatePlaythroughOK");
            break;
        case MPMovieLoadStateStalled:
            loadStateName = @"stalled";
            NSLog(@"MPMovieLoadStateStalled");
            break;
        default:
            break;
    }
    
    [self triggerEventsJavaScript:loadStateName WithValue:nil];
    
    NSLog(@"triggerLoadPlabackEvents Exit");
}

- (void)triggerMoviePlabackEvents: (NSNotification *)note {
    NSLog(@"triggerMoviePlabackEvents Enter");
    
    NSString *playBackName = [[NSString alloc]init];
    
    
    if (isSeeking) {
        isSeeking = NO;
        playBackName = @"seeked";
        NSLog(@"MPMoviePlaybackStateStopSeeking");
        //called because there is another event that will be fired
        [self triggerEventsJavaScript:playBackName WithValue: nil];
    }
    
    switch ( player.playbackState ) {
        case MPMoviePlaybackStateStopped:
            isPlaying = NO;
            playBackName = @"stop";
            NSLog(@"MPMoviePlaybackStateStopped");
            break;
        case MPMoviePlaybackStatePlaying:
            isPlaying = YES;
            playBackName = @"play";
            NSLog(@"MPMoviePlaybackStatePlaying");
            break;
        case MPMoviePlaybackStatePaused:
            isPlaying = NO;
            playBackName = @"pause";
            NSLog(@"MPMoviePlaybackStatePaused");
            break;
        case MPMoviePlaybackStateInterrupted:
            playBackName = @"MPMoviePlaybackStateInterrupted";
            NSLog(@"MPMoviePlaybackStateInterrupted");
            break;
        case MPMoviePlaybackStateSeekingForward:
        case MPMoviePlaybackStateSeekingBackward:
            isSeeking = YES;
            playBackName = @"seeking";
            NSLog(@"MPMoviePlaybackStateSeeking");
            break;
        default:
            break;
    }
    
    [self triggerEventsJavaScript:playBackName WithValue:nil];
    
    NSLog(@"triggerMoviePlabackEvents Exit");
}

- (void)triggerFinishPlabackEvents:(NSNotification*)notification {
    NSLog(@"triggerFinishPlabackEvents Enter");
    
    NSString *finishPlayBackName = [[NSString alloc]init];
    NSNumber* reason = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    
    switch ( [reason intValue] ) {
        case MPMovieFinishReasonPlaybackEnded:
            finishPlayBackName = @"ended";
            NSLog(@"playbackFinished. Reason: Playback Ended");
            break;
        case MPMovieFinishReasonPlaybackError:
            finishPlayBackName = @"error";
            NSLog(@"playbackFinished. Reason: Playback Error");
            break;
        case MPMovieFinishReasonUserExited:
            finishPlayBackName = @"MPMovieFinishReasonUserExited";
            NSLog(@"playbackFinished. Reason: User Exited");
            break;
        default:
            break;
    }
    
    [self triggerEventsJavaScript:finishPlayBackName WithValue:nil];
    
    NSLog(@"triggerFinishPlabackEvents Exit");
}

- (void)triggerEventsJavaScript: (NSString *)eventName WithValue: (NSString *) eventValue{
    NSLog(@"triggerEventsJavaScript Enter");
    
    NSString* jsStringLog = [NSString stringWithFormat:@"trigger --> NativeBridge.videoPlayer.trigger('%@', '%@')", eventName, eventValue];
    NSLog(@"%@", jsStringLog);
    NSString* jsString = [NSString stringWithFormat:@"NativeBridge.videoPlayer.trigger('%@', '%@')", eventName, eventValue];
    [self writeJavascript: jsString];
    NSLog(@"triggerEventsJavaScript Exit");
}

- (void)setAttribute: (NSArray*)args{
    NSLog(@"setAttribute Enter");
    
    NSString *attributeName = [args objectAtIndex:0];
    Attribute attributeValue = [attributeName attributeNameEnumFromString];
    NSString *attributeVal;
    
    switch ( attributeValue ) {
        case src:
            attributeVal = [args objectAtIndex:1];
            playerSource = attributeVal;
            [ self setPlayerSource: [NSURL URLWithString: attributeVal] ];
            break;
        case currentTime:
            attributeVal = [args objectAtIndex:1];
            if( [player isPreparedToPlay] ){
                [ player setCurrentPlaybackTime: [attributeVal doubleValue] ];
            }
            break;
        case visible:
            attributeVal = [args objectAtIndex:1];
            [self visible: attributeVal];
            break;
      #if !(TARGET_IPHONE_SIMULATOR)
        case wvServerKey:
            wvSettings = [[WVSettings alloc] init];
            isWideVine = YES;
            [ [NSNotificationCenter defaultCenter] addObserver: self
                                                      selector: @selector(playWV:)
                                                          name: @"wvResponseUrlNotification"
                                                        object: nil ];
            attributeVal = [args objectAtIndex:1];
            [self initWV: playerSource andKey: attributeVal];
            break;
        #endif
          
        default:
            break;
    }
    
    NSLog(@"setAttribute Exit");
}

- (void) onMovieDurationAvailable:(NSNotification *)notification {
    
}

- (void)setPlayerSource: (NSURL *)src{
    NSLog(@"setPlayerSource Enter");
    [player setContentURL:src];
    
    NSLog(@"setPlayerSource Exit");
}

- (void)resizePlayerView: (CGFloat)top right:(CGFloat)right width:(CGFloat)width height:(CGFloat)height{
    NSLog(@"resizePlayerView Enter");
    
    originalViewControllerFrame = CGRectMake( top, right, width, height );
    
    if ( !isFullScreen ) {
        self.view.frame = originalViewControllerFrame;
        self.player.view.frame = CGRectMake( 0, 0, width, height );
        self.webView.frame = self.player.view.frame;
    }
    
    NSLog(@"resizePlayerView Exit");
}

-(void)visible:(NSString *)boolVal{
    NSLog(@"visible Enter");
    
    [self triggerEventsJavaScript:@"visible" WithValue:[NSString stringWithFormat:@"%@", boolVal]];
    
    NSLog(@"visible Exit");
}

- (void) volumeChanged:(NSNotification *)notification {
    NSLog(@"onMovieDurationAvailable Enter");
    
    float volume = [[[notification userInfo]
                     objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"]
                    floatValue];
    
    if ( volume > prevVolume) {
        [self volumeUpChromecast];
    } else if ( volume < prevVolume) {
        [self volumeDownChromecast];
    }
    
    prevVolume = volume;
    
    NSLog(@"onMovieDurationAvailable Exit");
}

- (void) sendCurrentTime:(NSTimer *)timer {
    //    NSLog(@"sendCurrentTime Enter");
    
    if (([UIApplication sharedApplication].applicationState == UIApplicationStateActive) && (player.playbackState == MPMoviePlaybackStatePlaying)) {
        CGFloat currentTime = player.currentPlaybackTime;
//        [self triggerEventsJavaScript:@"timeupdate" WithValue:[NSString stringWithFormat:@"%f", currentTime]];
        
        if (chromecastDeviceController) {
            [chromecastDeviceController updateStatsFromDevice];
            float currTime = (chromecastDeviceController.streamPosition / chromecastDeviceController.streamDuration) * 1000;
            [ self triggerEventsJavaScript:@"timeupdate" WithValue: [NSString stringWithFormat:@"%f", currTime] ];
        }
    }
    
    //    NSLog(@"sendCurrentTime Exit");
}

- (void) updatePlaybackProgressFromTimer:(NSTimer *)timer {
    //    NSLog(@"updatePlaybackProgressFromTimer Enter");
    
    if (([UIApplication sharedApplication].applicationState == UIApplicationStateActive) && (player.playbackState == MPMoviePlaybackStatePlaying)) {
        CGFloat progress = player.playableDuration / player.duration;
//        [self triggerEventsJavaScript:@"progress" WithValue:[NSString stringWithFormat:@"%f", progress]];
        //        NSLog(@"%@", [NSString stringWithFormat:@"progress:%f", progress]);
    }
    
    //    NSLog(@"updatePlaybackProgressFromTimer Exit");
}

- (void)stopAndRemovePlayer{
    NSLog(@"stopAndRemovePlayer Enter");
    
    [self visible:@"false"];
    [player stop];
    [player setContentURL:nil];
    [player.view removeFromSuperview];
    [self.webView removeFromSuperview];
    
    if(isFullScreen){
        isFullScreen = NO;
    }
    
    player = nil;
    self.webView = nil;
    
    NSLog(@"stopAndRemovePlayer Exit");
}

-(void)showChromecastDeviceList{
    NSLog(@"");
    if ( chromecastDeviceController ) {
        [chromecastDeviceController chooseDevice: self];
    }
}

- (void)doneFSBtnPressed {
    NSLog(@"doneFSBtnPressed Enter");
    
    isCloseFullScreenByTap = YES;
    [self closeFullScreen];
    
    NSLog(@"doneFSBtnPressed Exit");
}

- (BOOL)isIpad{
    
    return ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
}

- (BOOL)isIOS7{
    
    if ( floor( NSFoundationVersionNumber ) <= NSFoundationVersionNumber_iOS_6_1 ) {
        return NO;
    }
    
    return YES;
}

#pragma mark - WideVine Methods
#if !(TARGET_IPHONE_SIMULATOR)

-(void)initWideVineParams {
    NSLog(@"initWideVineParams Enter");
    
    isWideVine = NO;
    isWideVineReady = NO;
    
    NSLog(@"initWideVineParams Exit");
}

- (void) initWV: (NSString *)src andKey: (NSString *)key {
    NSLog(@"initWV Enter");
    
    WViOsApiStatus *wvInitStatus = [wvSettings initializeWD: key];
    
    if (wvInitStatus == WViOsApiStatus_OK) {
        NSLog(@"widevine was inited");
    }
    
    [wvSettings playMovieFromUrl: src];
    
    NSLog(@"initWV Exit");
}

-(void)playWV: (NSNotification *)responseUrlNotification  {
    NSLog(@"playWV Exit");
    
    [ self setPlayerSource: [ NSURL URLWithString: [ [responseUrlNotification userInfo] valueForKey: @"response_url"] ] ];
    isWideVineReady = YES;
    
    if ( isPlayCalled ) {
        [self play];
    }
    
    NSLog(@"playWV Exit");
}

#endif

#pragma mark -

-(void)didPinchInOut:(UIPinchGestureRecognizer *) recongizer {
    NSLog( @"didPinchInOut Enter" );
    
    if (isFullScreen && recongizer.scale < 1) {
        [self toggleFullscreen];
    } else if (!isFullScreen && recongizer.scale > 1) {
        [self toggleFullscreen];
    }
    
    NSLog( @"didPinchInOut Exit" );
}

@end

@implementation NSString (EnumParser)

- (Attribute)attributeNameEnumFromString{
    NSLog(@"attributeNameEnumFromString Enter");
    
    NSDictionary *Attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInteger:src], @"src",
                                [NSNumber numberWithInteger:currentTime], @"currentTime",
                              #if !(TARGET_IPHONE_SIMULATOR)
                                    [NSNumber numberWithInteger:wvServerKey], @"wvServerKey",
                                #endif
                                nil
                                ];
    NSLog(@"attributeNameEnumFromString Exit");
    return (Attribute)[[Attributes objectForKey:self] intValue];
}

@end
