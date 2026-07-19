# Gratia 1.0 MVP Engineering Audit Report

- **Baseline Commit**: `release/1.0@463a420fb2cf77ca9f6ff2a181a09b8fa37ff69b`
- **Audit Branch**: `codex/ag-011-mvp-engineering-audit`
- **Worktree Location**: `worktrees/ag-011-mvp-engineering-audit`
- **Auditor**: `ANTIGRAVITY`

---

## 1. Test Execution & Build Verification

### GratiaCore Test Suite (Swift Testing)
- **Command**:
  ```bash
  swift test --package-path ios/Packages/GratiaCore --scratch-path /private/tmp/gratia-ag011-core --disable-xctest --enable-swift-testing
  ```
- **Results**: **17 / 17 tests passed** (0 failures, 0 skips, 0 unexpected).
- **Duration**: ~5.8s build, test run completed in 0.006s.

### Gratia App Test Suite (XCTest)
- **Command**:
  ```bash
  xcodebuild -project ios/Gratia.xcodeproj -scheme Gratia -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/gratia-ag011-derived -resultBundlePath /private/tmp/gratia-ag011.xcresult test
  ```
- **Results**: **23 / 23 tests passed** (0 failures, 0 skips, 0 unexpected).
- **Duration**: ~32.8s build & run.
- **XcodeBuild Output**: `** TEST SUCCEEDED **`
- **Test Results Bundle**: `/private/tmp/gratia-ag011.xcresult`

### Compiler Parser Check
- **Command**:
  ```bash
  swiftc -frontend -parse ios/Gratia/*.swift
  ```
- **Results**: Succeeded with **0 errors**.

### Formatting & Warnings Audit
- **Trailing Whitespaces**: `git diff --check` succeeded with **0 format issues**.
- **Build Warnings**: Found 4 minor compiler/linker notices:
  1. `warning: Metadata extraction skipped, no AppIntents.framework dependency found` (from `appintentsmetadataprocessor`, safe to ignore).
  2. `ld: warning: building for iOS-simulator-16.0, but linking with dylib '@rpath/XCTest.framework/XCTest' which was built for newer version 17.0` (harmless link warnings on the test target).
  3. `ld: warning: building for iOS-simulator-16.0, but linking with dylib '@rpath/libXCTestSwiftSupport.dylib' which was built for newer version 17.0`.

---

## 2. UI-to-API Mapping Matrix

| Dock Index & Label | View File | ViewModel | Core API Method | Backend Endpoint & Method | Response / Success UI Page |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0. 首页** (Lucide `TabHouse`) | [HomeView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/HomeView.swift) | None | None | None | None (Shows empty/feed based on local array) |
| **1. 搜索** (Lucide `TabSearch`) | [SearchView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/SearchView.swift) | None | None | None | Local Search Results Flow |
| **2. 发布** (Lucide `TabPublish`) | [PublishView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/PublishView.swift) | `PublishWishViewModel` | `createWish` | `POST /api/wishes` | `successView` (Shows `publicCode` & Copy CTA) |
| **3. 帮助** (Lucide `TabHandshake`) | [NearbyView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/NearbyView.swift) | `WishListViewModel` | `listWishes` | `GET /api/wishes` | Wish List Card / Detail View |
| **3. 帮助 - 详情响应表单** | `ApplyResponseSheet` | `WishResponseViewModel` | `createWishResponse` | `POST /api/wishes/{id}/responses` | `ApplySuccessView` ("等待运营确认...") |
| **4. 我的** (Lucide `TabUserRound`) | [ProfileView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/ProfileView.swift) | None | None | None | Account / Support navigation items |
| **4. 我的 - 我发布的** | `MyActivityView` | None | None | None | Directs user to "公开编号查询" |
| **4. 我的 - 进度查询** | [ProgressView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/ProgressView.swift) | `TrackWishViewModel` | `trackWish` | `POST /api/wishes/track` | Timeline events & delivery preview entry |

---

## 3. Engineering Gaps & Breaks

### 1. No API Endpoint for Public Stories (Home/Search)
- **Symptom**: `HomeView` and `SearchView` are fully static and read stories from `StoryFeedSource.stories`.
- **Engineering Break**: There is no backend endpoint mapping for loading completed/public stories. The `listWishes` endpoint in `WishAPIClient` only retrieves active wishes (`matching` status).
- **Conclusion**: Home and Search remain purely client-side mock/demonstration components for MVP. Production builds return `[]`, satisfying the honest empty state requirement.

### 2. Missing Local Cache for User Activity
- **Symptom**: `MyActivityView` renders a static empty state for both "我发布的" and "我帮助的".
- **Engineering Break**: The app has no local storage mechanism (e.g., UserDefaults or Keychain) to store the user's generated `publicCode` and `contact` values. Whenever the user leaves the sheet, they must re-enter credentials to track progress.
- **Conclusion**: Implementing a local cache of queried/created wish IDs is a critical MVP usability enhancement, though currently blocked by the strict "no local storage aggregation" privacy note.

### 3. Non-Lucide Elements in the Timeline
- **Symptom**: `ProgressView.swift` (lines 267-274) renders timeline progress using SF Symbols:
  ```swift
  Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
  ```
- **Conclusion**: If strict design rules mandate Lucide-only shapes across all page elements (not just the Dock), these need to be converted to local template images or custom Vector Shapes.

### 4. Deliverable Media Token Exposure
- **Symptom**: `DeliveryPreviewView.swift` passes `deliverable.url` directly to SwiftUI's `AsyncImage` or `VideoPlayer`.
- **Engineering Break**: If the R2 delivery URL requires query-string tokens (e.g. presigned URLs), these are exposed directly within the memory space of the player.
- **Conclusion**: The current code relies on simple HTTP transport of the media. No credential sanitization is active at the view layer.

---

## 4. Search & Security Findings

We audited the production files (`ios/Gratia`, `ios/Packages/GratiaCore/Sources`) for sensitive tokens, mock configurations, and hardcoded values:

1. **`StoryFeedSource.stories`**:
   - `HomeView` and `SearchView` query `StoryFeedSource.stories`.
   - In production, it cleanly returns `[]`. Under `DEBUG`, it returns `demoStories` only when `--demo-stories` argument is specified.
2. **`Wish.mockWishes`**:
   - Replaced entirely by `static var mockWishes: [Wish] = []` in [Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-011-mvp-engineering-audit/ios/Gratia/Models.swift#L18). No active mock wish items exist in production app scope.
3. **Production API URL**:
   - Hardcoded in `WishAPIClient.swift` (line 14): `https://haluowode-mvp.hanselzzh.workers.dev`
4. **Secret Keys**:
   - Zero hardcoded tokens, Cloudflare credentials, admin keys (`x-admin-key`), or API keys were found in the production targets.

---

## 5. Specification for the First Implementation Slice

We propose the following **P0 Implementation Slice** to bridge the MVP flow: **User Activity Local Cache (UserDefaults-backed)**.

### Allowed Files
- `ios/Gratia/ProfileView.swift`
- `ios/Gratia/PublishWishViewModel.swift`
- `ios/Gratia/TrackWishViewModel.swift`
- 新建 `ios/Gratia/UserActivityStorage.swift` (or similar helper helper)

### Invariants
- `WishAPIProtocol` contracts remain unchanged.
- No network requests are made outside `WishAPIClient`.
- No sensitive user contacts are written to storage (only the tuple `(publicCode, scene, city, landmark)` of successfully published wishes).

### Test Matrix
- Unit tests verifying that:
  1. Successful `createWish` result saves the public code to local storage.
  2. `MyActivityView` displays the cached items locally.
  3. Deleting/clearing cache functions correctly.

### Rollback Point
- Clean checkout of `release/1.0@463a420`.
