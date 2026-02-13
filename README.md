# Ayaat (آيات) - Daily Quranic Verses

<div align="center">
  <img src="assets/icon.png" alt="Ayaat App Icon" width="120">
  <br><br>
  <h1>Ayaat - Daily Quran Reading Reminders</h1>
  <p>A beautifully designed Flutter application to remind you to read the Quran at specific set times, helping you stay connected with the Book of Allah.</p>
</div>

---

## 🌟 Features

### 📖 Daily Inspiration
- **Verse of the Day**: Receive a carefully selected Ayah every day.
- **Multi-language Support**: Read verses in **Arabic**, **English**, and **French**.
- **Beautiful Typography**: Uses **Amiri** for Arabic script and **Outfit/Inter** for modern legibility.
- **Interactive UI**: Scroll through verses with smooth animations and "Continue Reading" functionality.

### 🕌 Prayer Times & Notifications
- **Accurate Calculations**: Uses the `adhan` package to calculate prayer times based on your precise location.
- **Smart Reminders**: Get notified **30 minutes after** each prayer time (Fajr, Dhuhr, Asr, Maghrib, Isha).
- **Manual Mode**: Option to set custom fixed notification times if preferred.

### 🎨 Premium User Experience
- **Elegant Dark Theme**: A sophisticated user interface with Deep Blue and Gold accents (`#0D1B2A` & `#1A237E`).
- **Custom Time Picker**: A bespoke, "original" scrolling wheel input for setting times, replacing standard OS pickers.
- **Smooth Animations**: Polished transitions and interactive elements.

## 🛠️ Tech Stack
- **Framework**: Flutter (Dark/Light mode support).
- **State Management**: `setState` & localized state.
- **Location**: `geolocator` for prayer time accuracy.
- **Notifications**: `flutter_local_notifications` with exact alarm scheduling (`AlarmManager` on Android).
- **Storage**: `shared_preferences` for saving user settings.

## 🚀 Getting Started

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/TechHookDev/Ayaat.git
    cd ayaat
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    flutter run
    ```
    *(Note: Location permissions are required for Prayer Times features)*

## 📸 Screenshots

<p align="center">
  <img src="assets/screenshot_welcome.png" width="200" alt="Welcome Screen" />
  &nbsp;&nbsp;
  <img src="assets/screenshot_home.png" width="200" alt="Home Screen" />
  &nbsp;&nbsp;
  <img src="assets/screenshot_surah_list.png" width="200" alt="Full Mushaf" />
</p>

<p align="center">
  <img src="assets/screenshot_settings.png" width="200" alt="Settings Screen" />
  &nbsp;&nbsp;
  <img src="assets/screenshot_picker.png" width="200" alt="Time Picker" />
</p>

---
Developed with ❤️ by **[Techhook](https://techhook.dev)**.
