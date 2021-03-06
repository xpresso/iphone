    //
//  YMNetworksViewController.m
//  Yammer
//
//  Created by Samuel Sutch on 4/22/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "YMNetworksViewController.h"
#import "YMWebService.h"
#import "YMAccountsViewController.h"
#import "UIColor+Extensions.h"
#import "YMNetworkTableViewCell.h"
#import "YMMessageListViewController.h"
#import "CFPrettyView.h"
#import "StatusBarNotifier.h"
#import "UIColor+Extensions.h"
#import "YMContactsListViewController.h"
#import "YMFeedListViewController.h"
#import <AddressBook/AddressBook.h>
#import "SQLiteInstanceManager.h"
#import "YMSettingsViewController.h"

@interface YMNetworksViewController (PrivateParts)

- (NSArray *)_allAddressBookContacts;
- (YMAccountsViewController *)accountsController;

@end


@implementation YMNetworksViewController

@synthesize web, onChooseNetwork;

- (IBAction)gotoAccounts:(UIControl *)sender
{
  [self.navigationController pushViewController:
   [self accountsController] animated:YES];
}

- (YMAccountsViewController *)accountsController 
{
  if (!accountsController) accountsController = [[YMAccountsViewController alloc] init];
  return accountsController;
}

- (void)refreshNetworks
{
  [self.tableView reloadData];
  if (updatingNetworks) return;
  
  NSArray *accounts = [YMUserAccount allObjects];
  NSMutableArray *ops = [NSMutableArray array];
  for (YMUserAccount *acct in accounts) {
    [ops addObject:[[YMWebService sharedWebService] networksForUserAccount:acct]];
  }
  updatingNetworks = YES;
  [[[[StatusBarNotifier sharedNotifier] 
     flashLoading:@"Updating Networks..."
     deferred:[DKDeferred gatherResults:ops]]
    addCallback:callbackTS(self, doneUpdatingAccounts:)]
   addBoth:callbackTS(self, _resetUpdatingNetworks:)];
}

- (id)_resetUpdatingNetworks:(id)r
{
  NSLog(@"doneUpdatingNetworks");
  updatingNetworks = NO;
  return r;
}

//- (void)didBecomeActive:(id)n
//{
  //[self refreshNetworks];
//}

- (id)doneUpdatingAccounts:(id)r
{
  [self.tableView reloadData];
  return r;
}

- (id)init
{
  if ((self = [super init])) {
    self.title = @"Networks";
    animateNetworkTransition = YES;
    networkPKs = nil;
    style = UITableViewStylePlain;
    onChooseNetwork = nil;
    updatingNetworks = NO;
    

    wasInactive = NO;
    
    if (&UIApplicationWillEnterForegroundNotification != NULL) {
      [[NSNotificationCenter defaultCenter]
       addObserver:self selector:@selector(didBackground:) name:
       UIApplicationDidEnterBackgroundNotification object:nil];
      [[NSNotificationCenter defaultCenter]
       addObserver:self selector:@selector(didBecomeActive:) name:
       UIApplicationDidBecomeActiveNotification object:nil];
    }
  }
  return self;
}

- (void)didBackground:(id)n { wasInactive = YES; }
- (void)didBecomeActive:(id)n {
  if (wasInactive) [self refreshNetworks];
}

- (id)initWithStyle:(UITableViewStyle)_style
{
  if ((self = [super initWithStyle:_style])) {
    self.title = @"Networks";
    animateNetworkTransition = YES;
    networkPKs = nil;
    style = _style;
    onChooseNetwork = nil;
    wasInactive = NO;
    
    if (&UIApplicationWillEnterForegroundNotification != NULL) {
      [[NSNotificationCenter defaultCenter]
       addObserver:self selector:@selector(didBackground:) name:
       UIApplicationDidEnterBackgroundNotification object:nil];
      [[NSNotificationCenter defaultCenter]
       addObserver:self selector:@selector(didBecomeActive:) name:
       UIApplicationDidBecomeActiveNotification object:nil];
    }
  }
  return self;
}

- (void)loadView
{
  self.tableView = [[[UITableView alloc] initWithFrame:
                     CGRectMake(0, 0, 320, 480) style:style] autorelease];
  self.tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight);
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.backgroundColor = [UIColor whiteColor];
  self.title = @"Networks";
  if (UIUserInterfaceIdiomPad != UI_USER_INTERFACE_IDIOM()) {
    self.navigationItem.rightBarButtonItem = 
      [[[UIBarButtonItem alloc]
        initWithTitle:@"Accounts" style:UIBarButtonItemStylePlain 
        target:self action:@selector(gotoAccounts:)] autorelease];
    self.navigationItem.leftBarButtonItem =
    [[[UIBarButtonItem alloc]
      initWithTitle:@"Settings" style:
      UIBarButtonItemStyleBordered target:self action:
      @selector(showSettings:)] autorelease];
  }
  
  if (!web) web = [YMWebService sharedWebService];
}

- (void)showSettings:(id)s
{
  [self.navigationController pushViewController:
   [[[YMSettingsViewController alloc] init] autorelease] animated:YES];
}

- (UITabBarController *)tabs
{
  tabs = [[UITabBarController alloc] init];
  myMessagesController = [[YMMessageListViewController alloc] init];
  myMessagesController.tabBarItem = 
  [[[UITabBarItem alloc] initWithTitle:@"My Feed" image:
    [UIImage imageNamed:@"53-house.png"] tag:0] autorelease];
  myMessagesController.shouldUpdateBadge = YES;
  
  receivedMessagesController = [[YMMessageListViewController alloc] init];
  receivedMessagesController.tabBarItem = 
  [[[UITabBarItem alloc] initWithTitle:@"Direct" image:
    [UIImage imageNamed:@"privateinbox.png"] tag:1] autorelease];
  receivedMessagesController.shouldUpdateBadge = YES;
  
  directoryController = [[YMContactsListViewController alloc] init];
  directoryController.tabBarItem =
  [[[UITabBarItem alloc] initWithTitle:@"Directory" image:
    [UIImage imageNamed:@"123-id-card.png"] tag:2] autorelease];
  
  feedsController = [[YMFeedListViewController alloc] init];
  feedsController.tabBarItem = 
  [[[UITabBarItem alloc] initWithTitle:@"Feeds" image:
    [UIImage imageNamed:@"feeds.png"] tag:3] autorelease];
  
  NSMutableArray *a = [NSMutableArray array];
  for (UIViewController *c in array_(myMessagesController, receivedMessagesController,
                                     feedsController, directoryController)) {
    [(id)c setUseSubtitleHeader:YES];
    UINavigationController *nav = [[[UINavigationController alloc] 
                                    initWithRootViewController:c] autorelease];
    nav.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
    [a addObject:nav];
    
    UIButton *back = [[[UIButton alloc] initWithFrame:CGRectMake(0, 0, 76, 30)] autorelease];
    back.titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    back.showsTouchWhenHighlighted = YES;
    back.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [back setTitleEdgeInsets:UIEdgeInsetsMake(0, 4, 0, 0)];
    [back setBackgroundImage:[[UIImage imageNamed:@"backbutton.png"] 
                              stretchableImageWithLeftCapWidth:17 topCapHeight:15]
                    forState:UIControlStateNormal];
    [back setBackgroundImage:[[UIImage imageNamed:@"backbutton-h.png"] 
                              stretchableImageWithLeftCapWidth:17 topCapHeight:15]
                    forState:UIControlStateHighlighted];
    [back setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

//    CGFloat max = 110.0;
//    CGFloat a = [last.name sizeWithFont:[UIFont boldSystemFontOfSize:12]].width;
//    if (a > max) a = max;
//    CGRect r = back.frame;
//    if (a > 64)
//      r.size.width += (a - 64.0) + 16.0;
//    if (r.size.width < 76.0) r.size.width = 76.0;
//    back.frame = r;
    [back setTitle:@"Networks" forState:UIControlStateNormal];
    [back addTarget:self action:@selector(dismissNetwork:) 
     forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *it = [[[UIBarButtonItem alloc] initWithCustomView:back] autorelease];
    
    c.navigationItem.leftBarButtonItem = it;
    
  }
  tabs.viewControllers = a;
  return tabs;
}

- (void)dismissNetwork:(id)s
{
  if (PREF_KEY(@"lastNetworkPK")) {
    YMNetwork *n = (YMNetwork *)[YMNetwork findByPK:
                                 intv(PREF_KEY(@"lastNetworkPK"))];
    if (n) {
      [[SQLiteInstanceManager sharedManager]
       executeUpdateSQL:
       [NSString stringWithFormat:
        @"UPDATE y_m_message SET read=1 WHERE network_p_k=%i", n.pk]];
    }
  }
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
  [defs removeObjectForKey:@"lastNetworkPK"];
  [defs synchronize];
  [self.navigationController dismissModalViewControllerWithAnimatedTransition:
   UIViewControllerAnimationTransitionMoveInFromLeft];
}

- (void) viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.view; // haha..
  [[StatusBarNotifier sharedNotifier] setTopOffset:460];
  self.navigationController.navigationBar.tintColor 
  = [UIColor colorWithRed:0.27 green:0.34 blue:0.39 alpha:1.0];
  self.navigationController.toolbar.tintColor 
  = [UIColor colorWithHexString:@"353535"];
  
  if (PREF_KEY(@"lastNetworkPK") 
      && UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    YMNetwork *n = (YMNetwork *)[YMNetwork findByPK:
                                 intv(PREF_KEY(@"lastNetworkPK"))];
    YMUserAccount *u = (YMUserAccount *)[YMUserAccount findByPK:intv(n.userAccountPK)];
    if (!u || !n) { // oh shit, something went very bad, force a reset
      SQLiteInstanceManager *db = [SQLiteInstanceManager sharedManager];
      [db executeUpdateSQL:@"DELETE FROM y_m_user_account"];
      [db executeUpdateSQL:@"DELETE FROM y_m_network"];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastNetworkPK"];
      [self.tableView reloadData];
      return;
    }
    
    animateNetworkTransition = NO;
    [self gotoNetwork:n];
    animateNetworkTransition = YES;
    return;
  }
  
  if (![[self.web loggedInUsers] count]) {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return;
    else {
      [self.navigationController pushViewController:
       [self accountsController] animated:NO];
    }
  }
  [self.tableView reloadData];
}

- (void) viewDidAppear:(BOOL)animated
{
  NSLog(@"networks appeared");
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastNetworkPK"];
  [[StatusBarNotifier sharedNotifier] setTopOffset:460];
  //[self.tableView reloadData];
  [self refreshNetworks];
  [super viewDidAppear:animated];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)table
{
  return 1;
}

- (NSInteger) tableView:(UITableView *)table 
numberOfRowsInSection:(NSInteger)section
{
  if (![[self.web loggedInUsers] count]) return 0;
  NSMutableArray *ar = [NSMutableArray array];
  for (YMUserAccount *acct in [web loggedInUsers]) {
    NSArray *pks = [YMNetwork pairedArraysForProperties:EMPTY_ARRAY 
                              withCriteria:@"WHERE user_account_p_k=%i", acct.pk];
    [ar addObjectsFromArray:[pks objectAtIndex:0]];
  }
  [networkPKs release];
  networkPKs = [ar retain];
  return [networkPKs count];
}

- (UITableViewCell *) tableView:(UITableView *)table
cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *ident = @"YMNetworkCell1";
  YMNetworkTableViewCell *cell;
  YMNetwork *network = (YMNetwork *)[YMNetwork findByPK:
                       intv([networkPKs objectAtIndex:indexPath.row])];
  
  cell = (YMNetworkTableViewCell *)[table dequeueReusableCellWithIdentifier:ident];
  if (!cell)
    cell = [[[YMNetworkTableViewCell alloc]
             initWithStyle:UITableViewCellStyleDefault
             reuseIdentifier:ident] autorelease];
  
  [cell.unreadLabel setHidden:NO];
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  cell.textLabel.text = network.name;
  int u = intv(network.unseenMessageCount), p = intv(network.unseenPrivateCount);
  int t = u + p;
  if (!t)
    [cell.unreadLabel setHidden:YES];
  else
    cell.unreadLabel.text = [NSString stringWithFormat:@"%i", t];
  
  return cell;
}

- (void) tableView:(UITableView *)table
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [table deselectRowAtIndexPath:indexPath animated:YES];
  
  YMNetwork *network = (YMNetwork *)[YMNetwork findByPK:
                       intv([networkPKs objectAtIndex:indexPath.row])];
  PREF_SET(@"lastNetworkPK", nsni(network.pk));
  PREF_SYNCHRONIZE;
  
  if (onChooseNetwork)
    [onChooseNetwork :network];
  else
    [self gotoNetwork:network];
}

- (void)gotoNetwork:(YMNetwork *)network
{
  YMUserAccount *acct = (YMUserAccount *)[YMUserAccount findByPK:
                                          intv(network.userAccountPK)];
  acct.activeNetworkPK = nsni(network.pk);
  [acct performSelector:@selector(save) withObject:nil afterDelay:5.0];
  [web performSelector:@selector(syncSubscriptions:) withObject:acct afterDelay:10.0];
  
  //[self doContactScrape:acct network:network];
  scrape_acct = acct;
  scrape_network = network;
  [self performSelector:@selector(doContactScrape) withObject:nil afterDelay:5.0];
  
  network.unseenMessageCount = nsni(0);
  [network performSelector:@selector(save) withObject:nil afterDelay:5.0];
  
  [web loadCachedContactImagesForUserAccount:acct];
  
  UITabBarController *c = !tabs ? [self tabs] : tabs;
  [c setSelectedIndex:0];
  
  myMessagesController.userAccount = acct;
  myMessagesController.target = YMMessageTargetFollowing;
  myMessagesController.title = @"My Feed";
  myMessagesController.network = network;
  myMessagesController.lastLoadedMessageID = nil;
  myMessagesController.remainingUnseenItems = nil;
  myMessagesController.lastSeenMessageID = nil;
  receivedMessagesController.userAccount = acct;
  receivedMessagesController.target = YMMessageTargetPrivate;
  receivedMessagesController.title = @"Direct";
  receivedMessagesController.network = network;
  receivedMessagesController.lastLoadedMessageID = nil;
  receivedMessagesController.remainingUnseenItems = nil;
  receivedMessagesController.lastSeenMessageID = nil;

  directoryController.userAccount = acct;
  feedsController.userAccount = acct;
  feedsController.network = network;
  for (id c in array_(myMessagesController, receivedMessagesController, directoryController, feedsController)) {
    NSLog(@"c.nav %@", [c navigationController]);
    [[c navigationController] popToRootViewControllerAnimated:NO];
  }
  
  if (animateNetworkTransition) {
    UIViewControllerAnimationTransition t = UIViewControllerAnimationTransitionPushFromRight;
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
      t = self.interfaceOrientation == UIInterfaceOrientationLandscapeRight 
        ? UIViewControllerAnimationTransitionPushFromTop : UIViewControllerAnimationTransitionPushFromBottom;
    [self.navigationController presentModalViewController:c withAnimatedTransition:t];
  } else {
    [self.navigationController presentModalViewController:c animated:NO];
  }
  
  myMessagesController.navigationItem.rightBarButtonItem = 
  [[UIBarButtonItem alloc]
   initWithBarButtonSystemItem:UIBarButtonSystemItemCompose 
   target:myMessagesController action:@selector(composeNew:)];
  
  [receivedMessagesController doReload:nil];
  [myMessagesController doReload:nil];
  
  [[StatusBarNotifier sharedNotifier] setTopOffset:411];
}

//- (void)doContactScrape:(YMUserAccount *)_acct network:(YMNetwork *)_network
//{
//  scrape_network = _network;
//  scrape_acct = _acct;
- (void)doContactScrape
{
  if (scrape_network.lastScrapedLocalContacts == nil && 
      !PREF_KEY(([NSString stringWithFormat:@"dontlookatmycontacts:%@", scrape_network.networkID])) && 
      !intv(scrape_network.community)) {
    [[[[UIAlertView alloc] initWithTitle:@"Yammer" message:
       @"Yammer would like to use your contacts to give you following suggestions." 
       delegate:self cancelButtonTitle:@"Don't Allow" otherButtonTitles:@"OK", nil] 
      autorelease] show];
  }
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == 0) PREF_SET(([NSString stringWithFormat:@"dontlookatmycontacts:%@", scrape_network.networkID]), nsnb(YES));
  else {
    scrape_network.lastScrapedLocalContacts = [NSDate date];
    [scrape_network save];
    [web suggestions:scrape_acct fromContacts:[self _allAddressBookContacts]];
    scrape_network = nil;
    scrape_acct = nil;
  }
}

- (NSArray *)_allAddressBookContacts
{
  NSMutableArray *ret = [NSMutableArray array];
  ABAddressBookRef addressBook = ABAddressBookCreate();
  CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
  
  CFStringRef fn, ln;
  CFArrayRef emails;
  ABRecordRef ref;
  ABMultiValueRef ems;
  NSString *name;
  
  for (int i = 0; i < CFArrayGetCount(people); i++) {
    ref = CFArrayGetValueAtIndex(people, i);
    
    fn = ABRecordCopyValue(ref, kABPersonFirstNameProperty);
    ln = ABRecordCopyValue(ref, kABPersonLastNameProperty);
    if (!ln) ln = CFSTR("");
    if (!fn) fn = CFSTR("");
    
    ems = ABRecordCopyValue(ref, kABPersonEmailProperty);
    emails = ABMultiValueCopyArrayOfAllValues(ems);
    if (!emails) emails = CFArrayCreate(NULL, NULL, 0, NULL);
    
    name = [NSString stringWithFormat:@"%@ %@", (id)fn, (id)ln];
    
    if ([name length] && CFArrayGetCount(emails))
      [ret addObject:
       dict_(name, @"name", 
             [NSArray arrayWithArray:(id)emails], @"addresses")];
    
    CFRelease(fn); 
    CFRelease(ln); 
    CFRelease(ems); 
    CFRelease(emails);
  }
  
  CFRelease(addressBook);
  CFRelease(people);
  
  return ret; 
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
  self.tableView = nil;
  [super viewDidUnload];
}


- (void)dealloc
{
  [accountsController release];
  [super dealloc];
}


@end
