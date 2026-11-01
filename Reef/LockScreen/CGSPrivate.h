#import <CoreGraphics/CoreGraphics.h>

// Private CoreGraphics / SkyLight window-server interfaces, declared here so
// Swift can call them. These are system APIs with no public headers; the
// signatures follow the long-standing shapes used by open-source window managers
// (yabai, CGSInternal). They are not stable across macOS releases, so the call
// site is feature-flagged and defensively torn down.
//
// Reef uses only enough to move its own display-only lock window into a fresh
// unmanaged space placed just above the lock shield's space, so it composites
// over the lock screen. It only ever operates on Reef's own window and own
// window-server connection, which is permitted with System Integrity Protection
// enabled (SIP only blocks acting on other apps' windows).

typedef int CGSConnectionID;
typedef unsigned long long CGSSpaceID;

CGSConnectionID CGSMainConnectionID(void);

// The sequence (matches the comparable notch app exactly):
//   space = CGSSpaceCreate(cid, 1, NULL);   // type 1 = unmanaged; type 0 fails under SIP
//   CGSSpaceSetAbsoluteLevel(cid, space, 400); // shield's space is level 300
//   CGSShowSpaces(cid, @[space]);
//   CGSAddWindowsToSpaces(cid, @[window], @[space]);
CGSSpaceID CGSSpaceCreate(CGSConnectionID cid, int type, CFDictionaryRef options);
void CGSSpaceDestroy(CGSConnectionID cid, CGSSpaceID sid);
void CGSSpaceSetAbsoluteLevel(CGSConnectionID cid, CGSSpaceID sid, int level);
void CGSShowSpaces(CGSConnectionID cid, CFArrayRef spaces);
void CGSHideSpaces(CGSConnectionID cid, CFArrayRef spaces);
void CGSAddWindowsToSpaces(CGSConnectionID cid, CFArrayRef windows, CFArrayRef spaces);
void CGSRemoveWindowsFromSpaces(CGSConnectionID cid, CFArrayRef windows, CFArrayRef spaces);
