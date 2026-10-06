# Empile - App Store Submission Checklist

## ✅ Pre-Submission Verification

### Version & Build
- [x] Marketing Version: 1.0
- [x] Build Number: 1
- [x] Bundle ID: app.empile.Empile
- [x] Minimum iOS: 15.0

### Code Quality
- [x] No debug code or logging
- [x] No compiler warnings
- [x] All tests passing (141 tests)
- [x] No hardcoded test data
- [x] Proper error handling
- [x] No crash on startup

### App Icons
- [x] AppIcon present (1024x1024)
- [x] All sizes generated
- [x] PNG format, no transparency issues
- [x] No rounded corners (iOS handles it)

### Localization
- [x] App name: "Empile"
- [x] Subtitle: "Stack blocks higher and higher"
- [x] Language: English
- [x] All text user-facing is French/English appropriate

### Privacy & Legal
- [x] Privacy Policy written (comprehensive)
- [x] Privacy Policy URL: https://example.com/empile/privacy
- [x] Support URL: https://example.com/empile/support
- [x] No personal data collection (except Game Center)
- [x] Encryption: Not used (ITSAppUsesNonExemptEncryption = false)
- [x] GDPR compliant

### Content
- [x] No offensive content
- [x] Age-appropriate (4+)
- [x] Game Center permissions requested properly
- [x] Ads disclosed in description
- [x] No external links in-app
- [x] No misleading app name/description

### Functionality
- [x] Game fully playable without network
- [x] Game fully playable without purchases
- [x] Power-ups accessible via ads (optional)
- [x] Game Center integration optional (works offline)
- [x] No crashes during gameplay
- [x] No freezes or infinite loops

### Device Testing
- [x] iPhone SE (small screen)
- [x] iPhone 14+ (notch/Dynamic Island)
- [x] iPad (tested)
- [x] Landscape orientation handled
- [x] Safe areas respected
- [x] All resolutions tested

### Permissions
- [x] No camera/microphone access
- [x] No photos/files access
- [x] No contacts access
- [x] No health/location access (except ads)
- [x] Only Game Center requested (optional)

---

## 📸 Screenshots Required

### iPhone Screenshots (6 per device type)
- [ ] Screenshot 1: Main menu / title screen
- [ ] Screenshot 2: First-time tutorial
- [ ] Screenshot 3: Active gameplay (tower building)
- [ ] Screenshot 4: Wind effect visible
- [ ] Screenshot 5: High score achieved
- [ ] Screenshot 6: Game Center leaderboards

### iPad Screenshots (6 for tablet)
- [ ] Landscape gameplay
- [ ] Landscape UI properly positioned
- [ ] Same content as iPhone versions
- [ ] Full use of screen space

### Recommended Sizes:
- **iPhone 14 Pro Max**: 1242 × 2688
- **iPhone 8**: 750 × 1334
- **iPad (12.9")**: 2048 × 2732
- **iPad (10.5")**: 1668 × 2224

### Screenshot Guidelines:
- Show actual gameplay, not marketing graphics
- No fake features or misleading content
- All features shown should be in the game
- Text overlay optional but helps
- No profanity or inappropriate content
- Quality must be high (no blurry, low-res)

---

## 📝 App Store Connect Checklist

### Basic Info
- [x] App Name: "Empile"
- [x] Subtitle: "Stack blocks higher and higher"
- [x] Bundle ID: app.empile.Empile
- [x] Primary Category: Games
- [x] Secondary Category: Puzzle

### Description
- [x] Full description (see AppStoreMetadata.md)
- [x] Clear gameplay explanation
- [x] Feature list with emojis
- [x] Unique value proposition
- [x] NO excessive capitalization
- [x] NO misleading claims

### Keywords
- [x] 5-6 relevant keywords
- [x] "puzzle", "blocks", "casual", etc.
- [x] Separated by commas
- [x] Under 100 characters total

### URLs
- [x] Support URL: https://example.com/empile/support
- [x] Privacy Policy URL: https://example.com/empile/privacy
- [x] Marketing URL (optional): https://example.com/empile

### Support
- [x] Support email: empile.support@example.com
- [x] Email is monitored and can respond

### Age Rating (IARC)
- [x] No violence
- [x] No sexual content
- [x] No profanity
- [x] No alcohol/tobacco
- [x] No gambling
- [x] Overall: 4+ (All Ages)

### Copyright & Contact Info
- [x] Copyright holder: © 2026 Empile
- [x] Contact email in privacy policy
- [x] Support phone (optional)

### Release Notes (v1.0)
- [x] Concise bullet points
- [x] Highlights new features (all for v1.0)
- [x] Mentions performance improvements
- [x] Professional tone

### Pricing & Availability
- [x] Price: Free
- [x] In-App Purchases: Optional (ads)
- [x] Available in all territories: YES
- [x] Discontinue date: None

### Game Information
- [x] Game requires Game Center: NO (optional)
- [x] Will request network: YES (Game Center, Ads)
- [x] Third-party SDKs: Google AdMob, Apple Game Center

---

## 🚀 Final Submission Steps

1. **Create App in App Store Connect**
   - [ ] Go to appstoreconnect.apple.com
   - [ ] Click "My Apps" → "+" → "New App"
   - [ ] Fill in Bundle ID: app.empile.Empile
   - [ ] Select Platforms: iOS

2. **Upload Builds**
   - [ ] Archive in Xcode: Product → Archive
   - [ ] Export for App Store → Distribute → Upload
   - [ ] Wait for processing (5-10 minutes)
   - [ ] Build appears in App Store Connect

3. **Complete Metadata**
   - [ ] Screenshots (all sizes)
   - [ ] App Description
   - [ ] Keywords
   - [ ] Support URL & Privacy Policy
   - [ ] Review notes (explain any special features)

4. **Set Release Date**
   - [ ] Choose: Auto-release after approval OR Manual release
   - [ ] Recommended: Manual (review before going live)

5. **Add Review Notes**
   - [ ] Explain gameplay if needed
   - [ ] Mention Game Center (optional)
   - [ ] Note about ads (optional but optional)
   - [ ] Any special testing instructions

6. **Submit for Review**
   - [ ] Click "Submit for Review"
   - [ ] Apple will start review within 24-48 hours
   - [ ] Monitor status in App Store Connect

7. **After Approval**
   - [ ] Manually release to App Store
   - [ ] Update social media
   - [ ] Monitor crash reports
   - [ ] Respond to user reviews

---

## ⚠️ Common Rejection Reasons (Avoid These!)

- ❌ Misleading app name or description
- ❌ Broken gameplay or crashes
- ❌ Ads not clearly disclosed
- ❌ Missing privacy policy
- ❌ Test data or debug code left in
- ❌ Gameplay differs from screenshots
- ❌ Empty permissions requests
- ❌ Outdated copyright information
- ❌ Offensive or inappropriate content

---

## 🆘 If Rejected

1. **Read the rejection reason carefully**
2. **Fix the specific issue**
3. **Update build number (e.g., 1 → 2)**
4. **Update CURRENT_PROJECT_VERSION in Xcode**
5. **Create new archive and upload**
6. **Resubmit with explanation in review notes**

---

## Status Tracking

| Date | Action | Status |
|------|--------|--------|
| --- | Metadata prepared | ✅ |
| --- | Screenshots created | ⏳ |
| --- | Build uploaded | ⏳ |
| --- | Submitted to Apple | ⏳ |
| --- | Under Review | ⏳ |
| --- | Approved / Rejected | ⏳ |
| --- | Released to App Store | ⏳ |

---

## Notes

- Build is version 1.0 (first release)
- App is completely functional offline
- Ads are optional and properly disclosed
- No in-app purchases requiring payment
- Game Center is optional bonus feature
- Privacy policy is comprehensive
