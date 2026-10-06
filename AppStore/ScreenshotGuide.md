# Empile - App Store Screenshot Guide

## Screenshot Requirements

### iPhone Screenshots
- **Sizes needed**: 1242 × 2688 (6.7" iPhone - largest)
- **Format**: PNG or JPG
- **Number of screenshots**: 6 per device type recommended
- **Language**: Same as App Store listing

### iPad Screenshots  
- **Sizes needed**: 2048 × 2732 (iPad 12.9")
- **Format**: PNG or JPG
- **Number of screenshots**: 6 recommended
- **Language**: Same as App Store listing

---

## How to Capture Screenshots

### Using Xcode Simulator

1. Open Empile in iPhone/iPad Simulator
2. **Simulator → Device → iPhone 15 Pro Max** (or iPad)
3. Play the game to reach desired screen
4. **Simulator → File → Save Screen Shot**
5. Or use `cmd + S` keyboard shortcut

### Batch Capture Script

```bash
# Create screenshots folder
mkdir -p AppStore/Screenshots

# Run simulator and capture at specific points
# Screenshot 1: Menu/Title screen
xcrun simctl screenshot <device-udid> AppStore/Screenshots/1-menu.png

# Screenshot 2: Tutorial
xcrun simctl screenshot <device-udid> AppStore/Screenshots/2-tutorial.png

# Screenshot 3: Gameplay
xcrun simctl screenshot <device-udid> AppStore/Screenshots/3-gameplay.png

# ... etc
```

---

## Screenshot Content & Order

### Screenshot 1: Title / Main Menu
**Purpose**: Hook the user immediately
- Show: Clean app title "Empile", colorful stack of blocks
- Caption: "Stack blocks higher and higher"
- Key message: "Simple, addictive puzzle gameplay"

### Screenshot 2: First-Time Tutorial
**Purpose**: Explain how to play
- Show: Pulsing ring on waiting piece, tutorial instruction
- Caption: "Easy to learn, fun to master"
- Key message: "Drag to aim, release to place"

### Screenshot 3: Active Gameplay
**Purpose**: Show engaging gameplay
- Show: Growing tower, next pieces, score
- Caption: "Build your tallest tower yet"
- Key message: "Strategic placement matters"

### Screenshot 4: Wind Physics
**Purpose**: Highlight unique feature
- Show: Wind gust affecting tower, streaks visible
- Caption: "Wind tests your tower's stability"
- Key message: "Master the elements"

### Screenshot 5: High Score / Victory
**Purpose**: Show reward satisfaction
- Show: Game Over screen with high score
- Caption: "Beat your personal best"
- Key message: "Compete with yourself and friends"

### Screenshot 6: Game Center Leaderboard
**Purpose**: Show multiplayer competition
- Show: Game Center leaderboards or achievement screen
- Caption: "Compete globally with Game Center"
- Key message: "Challenge your friends"

---

## Text Overlay Guidelines

### Best Practices
- **Keep it brief**: 1-3 words max per caption
- **Use bold, clean fonts**: System fonts work well
- **High contrast**: Light text on dark, dark on light
- **Position**: Top or bottom, never center where gameplay is
- **Size**: 40-60 pt for clarity on iPhone screenshots

### Recommended Captions (with emojis)
1. "Stack Higher" 🏗️
2. "Learn Fast" 📚
3. "Build Strategy" 🎮
4. "Master Elements" 🌪️
5. "Reach Top Scores" 🏆
6. "Compete Globally" 🌍

---

## Resizing Screenshots for App Store

### Using ImageMagick (CLI)
```bash
# Resize to iPhone 6.7" (1242 × 2688)
convert input.png -resize 1242x2688 output-iphone.png

# Resize to iPad 12.9" (2048 × 2732)
convert input.png -resize 2048x2732 output-ipad.png
```

### Using Preview (macOS)
1. Open screenshot in Preview
2. Tools → Adjust Size → Set width to 1242 or 2048
3. Aspect ratio will maintain
4. Export as PNG

### Using Python
```python
from PIL import Image

# Resize
img = Image.open('screenshot.png')
img_resized = img.resize((1242, 2688), Image.LANCZOS)
img_resized.save('screenshot-iphone.png')
```

---

## Pro Tips for Screenshots

✅ **DO:**
- Use actual gameplay, not marketing renders
- Show the most visually interesting moments
- Include UI so users see the real app
- Make each screenshot different (show variety)
- Ensure text is readable (40pt minimum)
- Use vibrant, colorful moments from the game
- Show progression: menu → tutorial → gameplay → victory

❌ **DON'T:**
- Edit gameplay to look unrealistically good
- Hide essential UI elements
- Use small, hard-to-read text
- Repeat the same scene multiple times
- Include any fake features
- Show glitches or errors
- Use copyrighted music/art not in app
- Mislead about what the app does

---

## Uploading to App Store Connect

1. Go to **appstoreconnect.apple.com**
2. Select your app → **Pricing and Availability**
3. Scroll to **Screenshots**
4. Click **"+" → Add Screenshot**
5. Select device type (iPhone 15 Pro Max, iPad, etc.)
6. Upload PNG/JPG (one at a time or batch)
7. Reorder if needed (drag and drop)
8. Repeat for each device type

---

## Quality Checklist

- [x] All 6 screenshots captured
- [x] No technical glitches visible
- [x] All screenshots are different
- [x] Text captions clear and visible
- [x] Screenshots show real gameplay (not edited)
- [x] Correct aspect ratio for device type
- [x] File size reasonable (< 5MB each)
- [x] PNG format for clarity
- [x] No watermarks or external logos

---

## File Organization

```
AppStore/
├── Screenshots/
│   ├── iPhone/
│   │   ├── 1-menu.png (1242x2688)
│   │   ├── 2-tutorial.png
│   │   ├── 3-gameplay.png
│   │   ├── 4-wind.png
│   │   ├── 5-score.png
│   │   └── 6-leaderboard.png
│   └── iPad/
│       ├── 1-menu.png (2048x2732)
│       └── ... (same as iPhone)
├── PrivacyPolicy.txt
├── AppStoreMetadata.md
└── SubmissionChecklist.md
```

---

## Next Steps

1. [ ] Launch Empile in simulator
2. [ ] Reach each key gameplay moment
3. [ ] Capture 6 high-quality screenshots per device
4. [ ] Resize to correct dimensions
5. [ ] Add subtle text captions (optional)
6. [ ] Upload to App Store Connect
7. [ ] Arrange in logical order
8. [ ] Review before submission
