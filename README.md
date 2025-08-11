# Solideo App - Food Ordering System

## 📱 About

Solideo App is a comprehensive mobile food ordering application built with Flutter and Firebase. It provides a seamless experience for customers to order food from RM Solideo Kuliner restaurant with features including real-time order tracking, multiple payment methods, and admin dashboard for restaurant management.

## ✨ Features

### Customer Features

- **User Authentication**: Secure login/register with email verification
- **Menu Browsing**: Browse through categorized food items with images and descriptions
- **Shopping Cart**: Add, remove, and modify items in cart
- **Order Management**: Place orders and track order status in real-time
- **Multiple Payment Methods**:
  - Cash on Delivery (COD)
  - Bank Transfer
  - Counter Payment
- **Order History**: View past orders and reorder favorites
- **Profile Management**: Update personal information and preferences

### Admin Features

- **Dashboard**: Comprehensive overview of restaurant statistics
- **Order Management**: View, accept, and update order status
- **Menu Management**: Add, edit, and remove menu items
- **Statistics & Analytics**:
  - Revenue tracking (daily, weekly, monthly)
  - Top 5 most ordered menu items
  - Order trends and insights
- **PDF Reports**: Generate and export revenue reports

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Firestore (Database)
  - Firebase Authentication
  - Firebase Storage
- **State Management**: Provider/SetState
- **Charts**: FL Chart
- **PDF Generation**: pdf package
- **Image Upload**: Cloudinary
- **UI Components**: Material Design

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=2.17.0)
- Android Studio / VS Code
- Firebase account
- Cloudinary account (for image uploads)

## 📊 Database Structure

### Firestore Collections

#### `users`

```json
{
  "uid": "string",
  "name": "string",
  "email": "string",
  "phone": "string",
  "address": "string",
  "role": "customer|admin",
  "createdAt": "timestamp"
}
```

#### `menu_items`

```json
{
  "name": "string",
  "description": "string",
  "price": "number",
  "image": "string",
  "category": "string",
  "available": "boolean",
  "orders": "number"
}
```

#### `orders`

```json
{
  "orderId": "string",
  "userId": "string",
  "items": [
    {
      "menuId": "string",
      "name": "string",
      "quantity": "number",
      "price": "number",
      "subtotal": "number"
    }
  ],
  "totalAmount": "number",
  "status": "pending|confirmed|preparing|ready|completed|cancelled",
  "paymentMethod": "cod|transfer|counter",
  "paymentStatus": "pending|paid|failed",
  "orderTime": "timestamp",
  "customerInfo": {
    "name": "string",
    "phone": "string",
    "address": "string"
  }
}
```

## 🔧 Configuration

### Firebase Configuration

⚠️ **IMPORTANT SECURITY NOTICE**: 
- Never commit `google-services.json` or `firebase_options.dart` with real API keys to Git
- Use the provided template files and replace with your actual Firebase configuration
- Keep your Firebase API keys secure and regenerate them if compromised

**Setup Steps:**
1. Copy `lib/firebase_options.dart.template` to `lib/firebase_options.dart`
2. Copy `android/app/google-services.json.template` to `android/app/google-services.json`
3. Replace all placeholder values with your actual Firebase configuration:
   - `YOUR_ANDROID_API_KEY` → Your actual Android API key
   - `YOUR_IOS_API_KEY` → Your actual iOS API key  
   - `YOUR_PROJECT_ID` → Your Firebase project ID
   - `YOUR_APP_ID` → Your app ID from Firebase console
   - Other placeholders with corresponding values
4. Configure Firestore security rules
5. Set up Firebase Authentication methods

### App Configuration

- Update app name and package name in `pubspec.yaml`
- Configure app icons and splash screens
- Update API endpoints and keys

## 📱 App Architecture

```
lib/
├── main.dart                 # App entry point
├── splash.dart              # Splash screen
├── firebase_options.dart    # Firebase configuration
└── src/
    ├── admin_statistics.dart # Admin dashboard & analytics
    ├── cart_service.dart     # Shopping cart logic
    ├── home.dart            # Main customer home page
    ├── menu_page.dart       # Menu browsing
    ├── order.dart           # Order management
    ├── order_detail.dart    # Order details view
    ├── profile.dart         # User profile
    ├── login.dart           # Authentication
    └── payment/
        ├── bank_transfer_page.dart
        └── counter_payment_page.dart
```

## 🔑 Key Features Implementation

### Real-time Order Tracking

- Uses Firestore real-time listeners
- Automatic status updates
- Push notifications for order updates

### Payment Integration

- Multiple payment methods
- Payment verification system
- Receipt generation

### Admin Analytics

- Revenue tracking with charts
- Order statistics
- Top menu items analysis
- PDF report generation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Developer

**Kevin Jeremi**

- GitHub: [@KevinJeremi](https://github.com/KevinJeremi)

**RM Solideo Kuliner** - Bringing delicious food to your doorstep! 🍽️
