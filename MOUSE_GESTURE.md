# Mouse Scroll Gesture in Menu Bar

## How It Works

The mouse scroll gesture works **ONLY when mouse is in the menu bar area** by:

1. **Calculating menu bar height** - `screenFrame.maxY - visibleFrame.maxY`
2. **Creating tracking window** - Positioned EXACTLY over the menu bar area
3. **NSTrackingArea** - Detects mouse entry/exit in menu bar
4. **Scroll monitoring** - Captures scroll events only when mouse is in menu bar
5. **No permissions needed** - Uses standard AppKit APIs

## Key Implementation Details

### Precise Menu Bar Tracking
```swift
// Menu bar starts where visible frame ends
let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

let trackingFrame = NSRect(
    x: screenFrame.origin.x,
    y: visibleFrame.maxY,  // Start of menu bar
    width: screenFrame.width,
    height: menuBarHeight  // Exact menu bar height
)
```

### Window Configuration
- **Level**: `.statusBar` - Same level as menu bar
- **ignoresMouseEvents**: `false` - Must receive events for tracking
- **Transparent**: Clear background, no shadow
- **Collection behavior**: Joins all spaces, stationary, ignores cycle

### Scroll Detection
- **Trigger**: Scroll UP (positive `scrollingDeltaY`) while mouse is in menu bar
- **Threshold**: 20 pixels of upward scroll
- **Reset**: Scrolling down reduces the accumulator
- **Activation**: Calls `mainPanel?.show()` when threshold reached

### Event Flow
1. Mouse enters menu bar → `mouseAtTop = true`, reset `scrollDelta`
2. User scrolls UP in menu bar → accumulate delta
3. Delta reaches 20px → trigger callback, show panel
4. Mouse leaves menu bar → `mouseAtTop = false`, reset `scrollDelta`

## Advantages

✅ **No Accessibility permissions** - Uses standard AppKit APIs  
✅ **Precise detection** - Only works in menu bar, not anywhere at top  
✅ **Event-driven** - No polling, no timers  
✅ **Menu bar remains functional** - Clicks pass through to menu items  
✅ **Works across all spaces** - Follows you everywhere  

## Console Output

When working correctly:
```
🔍 Starting MouseTracker...
   📏 Screen: 1728x1117
   📏 Visible frame top: 1090
   📏 Menu bar height: 27px
   📏 Tracking window: x=0 y=1090 w=1728 h=27
✅ Mouse tracker started!
   📍 Tracking ONLY in menu bar area
   📜 Scroll UP 20px in menu bar to activate
   ✨ No Accessibility permissions required!
```

When mouse enters menu bar:
```
🖱️ Mouse ENTERED menu bar area
```

When scrolling UP in menu bar:
```
📜 Scroll: 8.5 | In menu bar: true
   ⬆️ Scroll UP accumulated: 8.5/20
📜 Scroll: 6.2 | In menu bar: true
   ⬆️ Scroll UP accumulated: 14.7/20
📜 Scroll: 7.8 | In menu bar: true
   ⬆️ Scroll UP accumulated: 22.5/20
🎯 Threshold reached - activating panel!
```

## Customization

Edit these constants in `MouseTracker.swift`:

```swift
private let scrollThreshold: CGFloat = 20      // Scroll distance needed (pixels)
private let topEdgeThreshold: CGFloat = 50     // Height of detection zone (pixels)
```

Lower `scrollThreshold` = more sensitive  
Increase `topEdgeThreshold` = larger detection area
