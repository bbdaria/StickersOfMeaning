# Stickers of Meaning - Developer Documentation

## 1. Project Overview
"Stickers of Meaning" is a Flutter-based mobile application built to serve as a digital companion to the initiative honoring the victims of the Swords of Iron war. 

From a technical perspective, the app is a **content-delivery platform with heavy emphasis on native home-screen widgets**. It fetches data from a headless WordPress REST API (`stickersofmeaning.org/wp-json/wp/v2/`), allows users to cache content locally ("Pool/Collection"), and schedules background tasks to periodically update a native Android/iOS home screen widget.

### Tech Stack & Core Libraries
* **Framework:** Flutter (Dart)
* **State Management:** `provider`
* **Local Storage:** `shared_preferences` & local file storage (for caching images)
* **API/Networking:** `http`
* **Native Widgets:** `home_widget` (Bridges Flutter and Native widget data)
* **Background Tasks:** `workmanager` (Handles periodic widget updates)
* **Data Parsing:** `html_unescape` (Cleans WordPress HTML responses)

---

## 2. Architecture & File Structure

The project follows a standard service-oriented architecture. UI components are separated from business logic, which is handled by singleton-like Services injected via Provider.

### `lib/` (Flutter Codebase)

#### Entry Point & Configuration
* **`main.dart`**: The application entry point. It initializes core asynchronous services (`BackgroundService`, `PreferencesService`, `WidgetService`) before `runApp` is called. It wraps the app in a `MultiProvider` to make these services available globally.
* **`app.dart`**: The root app widget. It configures the `MaterialApp`, handles theming, internationalization (i18n) setup (English/Hebrew), and defines the named routes for all screens (e.g., `HomeScreen`, `PreferencesScreen`, `StickerPoolScreen`). It also wraps the app in a `ConnectivityWrapper` to handle offline states.

#### Models (`lib/models/`)
* **`sticker.dart`**: The core data model representing a sticker. 
  * **Important Developer Note:** The `fromJson` factory is complex because the WordPress REST API responses vary. It contains extensive fallback logic to find the quote content (checking `meta`, `title`, `content.rendered`, and `_embedded` media captions) and aggressively strips HTML tags using RegEx and `html_unescape`.

#### Services (`lib/services/`)
This is the "brain" of the application.
* **`api_service.dart`**: Handles all communication with the WordPress backend.
  * Fetches paginated sticker indexes, specific stickers by ID, categories, and handles search queries.
  * Contains the logic for `getDailySticker()` and `updateWidgetContent()`, deciding whether to pull a sticker from the user's local pool or fetch a random one from the web based on user filter preferences.
* **`preferences_service.dart`**: A massive `ChangeNotifier` that manages local state.
  * Handles user preferences (language, text size, widget styling, update intervals).
  * Manages the **Sticker Pool** (the user's saved collection).
  * **Important:** It actively caches images locally (`_downloadAndSaveImage`) when a sticker is saved to the pool, ensuring the widget can access the image even when offline.
  * Implements a file-based polling mechanism (`_startAutoReloadTimer` checking `widget_id.txt`) to sync widget state when the app is resumed.
* **`widget_service.dart`**: The bridge between Flutter and the Native Widget using the `home_widget` package.
  * Formats data (text, background color, text color, local image paths) and saves it to the native shared memory group (`group.stickers.of.meaning`).
  * Triggers the native widget refresh command.
* **`background_service.dart`**: Configures the `workmanager` package.
  * Defines the headless task `widgetUpdateTask` which runs in the background (even when the app is killed), instantiates the necessary services, and fetches a new sticker to update the native widget based on the user's refresh interval.

---

## 3. Native Platform Integrations

Because this app heavily relies on a Home Screen Widget, a significant portion of the rendering logic lives in the native code. 

### Android (`android/app/src/main/kotlin/com/example/stickers_of_meaning/`)
* **`StickerWidgetProvider.kt`**: The native Android AppWidgetProvider.
  * **Data Retrieval:** It reads the formatted data (colors, text, image paths, visibility flags) saved by Flutter's `WidgetService`.
  * **Dynamic UI Rendering:** It toggles between two states: "Image Mode" (shows the fallen's photo) and "Text Mode" (shows their quote with a customized background color and opacity).
  * **Dynamic Text Sizing (`calculateOptimalTextSize`):** A crucial custom function. Because widget sizes vary dynamically based on user resizing on their launcher, this function creates a `StaticLayout` and recursively shrinks the font size until the quote perfectly fits within the physical constraints of the widget.

*(Note: iOS native implementations will reside in the `ios/Runner/` directory following a similar bridging concept using App Groups and Swift/WidgetKit).*

---

## 4. Data Flow: How the Widget Updates

Understanding this flow is critical for debugging widget issues:

1. **Trigger:** An update is triggered either manually by the user, by the `PreferencesService` on init, or by the `BackgroundService` (`workmanager`) waking up the OS.
2. **Fetch:** `ApiService.updateWidgetContent()` evaluates the user's preferences. It checks if the source is set to "Web" or "My Collection" and filters by category.
3. **Download:** It selects a `Sticker` object. If the user wants to show images, it ensures the image is downloaded.
4. **Bridge:** `WidgetService.updateStickerWidget()` parses the sticker into primitive types (Strings, Ints for colors, Booleans) and uses `HomeWidget.saveWidgetData` to write to platform-specific shared storage.
5. **Render (Android):** `HomeWidget.updateWidget` broadcasts an intent. `StickerWidgetProvider.kt` catches it, reads the primitive data, calculates UI bounds, and pushes a `RemoteViews` update to the Android home screen.
