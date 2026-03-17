# Volunterra

**Volunterra** is a mobile app (currently) built for Android which connects volunteers with campaigns and helps organizers find enthusiastic people to join their cause.

## 🚀 Key Features

### 📱 Dynamic homepage custom built for the user
* **Latest Campaign:** Instantly view the most recently added campaign to keep up-to-date with new opportunities.
* **Smart Recommendations:** Tailored campaign suggestions based on your interests and previous participations.
* **User Activity Overview:** A quick glance at your recent volunteering actions, ongoing campaigns, and overall progress.

### 🔐 Authentication & User Management
* **Hybrid Auth System:** Supports Email/Password registration and Google / Facebook Sign-In.
* **Profile Management:** Users can edit their profiles, upload avatars, and track their progress.

### 📢 Campaign Management
* **Create Campaigns:** A guided, multi-step form (Wizard style) for organizers to create events:
    * *Step 1:* Basic Info (Title, Description)
    * *Step 2:* Date & Time selection with validation.
    * *Step 3:* Image upload and final review.
* **Browse & Filter:** Real-time feed of active campaigns.
* **Bookmarks:** Users can save campaigns to their personal list.
* **Admin Panel:** Allowing campaign organizers to manage their campaigns

### 💬 Real-Time Communication
* **Group Chats:** Every campaign has a dedicated chat room for accepted volunteers.
* **Push Notifications:** Keep up to date with device push notifications about changes in campaigns
* **Instant Updates:** Powered by Firestore streams for real-time messaging.

### 🎮 Gamification (Leveling System) - In development
* **XP System:** Volunteers earn experience points (XP) for participating in campaigns.
* **Levels:** Dynamic user levels based on contribution history, encouraging consistent volunteering.

---

## 🔮 Future Improvements

* [ ] Dark Mode and personalisation
* [ ] Gamification, experience levels, more social features
* [ ] Calendar Sync: Easily add upcoming volunteer events directly to your device's native calendar.
* [ ] iOS Release

---

## 🛠️ Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend / BaaS:** [Firebase](https://firebase.google.com/)
    * **Firebase Auth:** User identification.
    * **Cloud Firestore:** NoSQL database for storing users, campaigns, and chats.
    * **Firebase Storage:** Hosting campaign images and user avatars.

---

## 📥 Download & Install (For Users)

Want to try **Volunterra** right away without setting up the development environment? You can download the app directly to your Android device:

1. Navigate to the [Releases](https://github.com/ZvezdiPro/volunterra/releases) page of this repository.
2. Download the latest `.apk` file (e.g., `app-release.apk`) under the "Assets" section.
3. Open the downloaded file on your Android device and tap **Install** (you might need to allow installations from unknown sources in your settings).

---

## 🏁 Getting Started

To run this project locally:

### Prerequisites
* Flutter SDK installed.
* A Firebase project set up.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/ZvezdiPro/volunterra.git
    cd volunterra
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Setup:**
    * Create a project in the Firebase Console.
    * Add Android/iOS apps in the console.
    * Download `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS).
    * Place them in `android/app/` and `ios/Runner/` respectively.

4.  **Run the app:**
    ```bash
    flutter run
    ```

---

## 🏢 For NGOs & Organizations

We are constantly looking to expand our network of trusted partners! **Volunterra** provides specific tools designed to help Non-Governmental Organizations (NGOs) manage their events more efficiently.

### Why join us?
* **Targeted Audience:** Reach people specifically looking to volunteer in Varna and the region (and Bulgaria as a whole).
* **Management Tools:** Easily track participants and communicate with them via dedicated chat rooms.
* **Gamification:** Our XP system motivates volunteers to show up and perform well.

In order to join, please contact us at zvezdipenev@gmail.com and we'll create a special account as an NGO!

---
## 📫 Contact
### Developers:
* **Zvezdi** - *Lead Developer*
* **martinkab07** - Backend Dev + Tester [(github)](https://github.com/martinkab07)

Feel free to reach out if you have any questions or suggestions about the project!

* **Email:** zvezdipenev@gmail.com
* **GitHub:** [github.com/ZvezdiPro](https://github.com/ZvezdiPro)

Project Link: [https://github.com/ZvezdiPro/volunterra](https://github.com/ZvezdiPro/volunterra)
