# CalorieNaija iOS App

A native iOS wrapper for CalorieNaija (www.calorienaija.com) using WKWebView.

## Requirements

- Mac with Xcode 15+ installed
- Apple Developer Account (£79/year) - https://developer.apple.com/programs/enroll/
- iOS 16.0+ target

## How to Build & Submit to App Store

### Option A: Build on a Mac (recommended)

1. Transfer this folder to a Mac
2. Open `CalorieNaija.xcodeproj` in Xcode
3. Select your Apple Developer Team in Signing & Capabilities
4. Select "Any iOS Device" as build target
5. Product → Archive
6. Distribute App → App Store Connect → Upload
7. Go to App Store Connect and submit for review

### Option B: Use a Mac in the cloud (if you don't have a Mac)

- **MacStadium** (https://www.macstadium.com) - rent a Mac
- **GitHub Actions** with macOS runner (free for open source)
- **Codemagic** (https://codemagic.io) - CI/CD for iOS apps, free tier available

### Option C: Use Transloader or similar service

Some services will build and sign your iOS app for you without needing a Mac.

## App Store Connect Setup

1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: CalorieNaija - African Food Diary
   - Primary Language: English (UK)
   - Bundle ID: com.calorienaija.www
   - SKU: calorienaija-ios-v1
4. Upload screenshots (same ones used for Google Play work fine)
5. Fill in description, keywords, support URL
6. Submit for review

## Bundle Identifier

`com.calorienaija.www`

## Features

- Full-screen WebView loading calorienaija.com
- Back/forward swipe navigation
- Portrait orientation (iPhone), all orientations (iPad)
- Native status bar integration
- App Transport Security configured for calorienaija.com

## App Store Review Tips

- Apple may reject "simple WebView wrappers" - ensure your PWA has:
  - Offline functionality (service worker)
  - Push notifications
  - Native-feeling interactions
- CalorieNaija already has these as a PWA, so it should pass review
