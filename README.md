<p align="center">
  <img src="assets/images/logo.jpg" alt="Tart Lejen logo" width="120">
</p>

<h1 align="center">MYabah Tart Lejen</h1>

<p align="center">
  A Flutter and Firebase app for a Kuala Lumpur tart and snack shop.<br>
  Customers order from their phone, and staff run orders, stock and counter sales from the same app.
</p>

> All screenshots use made-up customers and orders.

## Customer app

Browse the menu, choose a size, check out with a voucher, then follow the order as it moves along.

<table>
  <tr>
    <td align="center"><img src="test_preview/shots/home_matcha_360.png" alt="Home screen" width="200"><br><b>Home</b></td>
    <td align="center"><img src="test_preview/shots/menu_matcha_360.png" alt="Menu with search and collections" width="200"><br><b>Menu</b></td>
    <td align="center"><img src="test_preview/shots/product_matcha_360.png" alt="Product page with size options" width="200"><br><b>Product</b></td>
  </tr>
  <tr>
    <td align="center"><img src="test_preview/shots/cart_matcha_360.png" alt="Cart with a voucher applied" width="200"><br><b>Cart</b></td>
    <td align="center"><img src="test_preview/shots/checkout_matcha_360.png" alt="Checkout with delivery options" width="200"><br><b>Checkout</b></td>
    <td align="center"><img src="test_preview/shots/order_active_matcha_360.png" alt="Order progress tracking" width="200"><br><b>Order tracking</b></td>
  </tr>
  <tr>
    <td align="center"><img src="test_preview/shots/orders_matcha_360.png" alt="Active and past orders" width="200"><br><b>Your orders</b></td>
    <td align="center"><img src="test_preview/shots/profile_matcha_360.png" alt="Profile and saved details" width="200"><br><b>Profile</b></td>
    <td align="center"><img src="test_preview/shots/signin_matcha_360.png" alt="Create account form" width="200"><br><b>Sign up</b></td>
  </tr>
</table>

- **Menu:** search, collections, S/M/L sizes and live stock counts
- **Checkout:** vouchers, plus delivery by the shop's team, Lalamove or store pickup
- **Payment:** cash on delivery or pay at pickup
- **After ordering:** status tracking, cancellations, refund requests and product reviews

## Kitchen mode

Staff accounts get a separate dark workspace for the day-to-day running of the shop.

<table>
  <tr>
    <td align="center"><img src="test_preview/shots/k_today_matcha_360.png" alt="Today's sales and waiting orders" width="200"><br><b>Today</b></td>
    <td align="center"><img src="test_preview/shots/k_orders_matcha_360.png" alt="Order queue by status" width="200"><br><b>Orders</b></td>
    <td align="center"><img src="test_preview/shots/k_counter_matcha_360.png" alt="Counter sales screen" width="200"><br><b>Counter</b></td>
  </tr>
  <tr>
    <td align="center"><img src="test_preview/shots/k_menu_matcha_360.png" alt="Menu and stock management" width="200"><br><b>Menu &amp; stock</b></td>
    <td align="center"><img src="test_preview/shots/k_report_matcha_360.png" alt="Sales report with a daily chart" width="200"><br><b>Sales report</b></td>
    <td align="center"><img src="test_preview/shots/k_more_matcha_360.png" alt="More staff tools" width="200"><br><b>More tools</b></td>
  </tr>
</table>

- **Orders:** move orders through each status from a single queue
- **Counter:** take walk-in sales by cash, e-wallet/QR or card, and choose what goes on the counter menu
- **Reports:** online and counter sales over 7, 30 or 90 days, plus best sellers
- **Shop management:** products, stock, collections, vouchers, customers, refunds, delivery fees and home page text

## App designs

Customers can pick from eight designs, and the choice is saved on their device. Each one changes the colours, fonts and corner shapes.

<table>
  <tr>
    <td align="center"><img src="test_preview/shots/home_matcha_360.png" alt="Matcha and Apricot design" width="150"><br>Matcha &amp; Apricot</td>
    <td align="center"><img src="test_preview/shots/home_caramel_360.png" alt="Caramel Classic design" width="150"><br>Caramel Classic</td>
    <td align="center"><img src="test_preview/shots/home_lavender_360.png" alt="Lavender and Lime design" width="150"><br>Lavender &amp; Lime</td>
    <td align="center"><img src="test_preview/shots/home_midnight_360.png" alt="Midnight Neon design" width="150"><br>Midnight Neon</td>
  </tr>
</table>

The others are Raspberry & Butter, Blueberry & Coral, Mono Volt and Aurora Glow.

## Getting started

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart 3.13.7 or newer. To deploy database rules, you also need the [Firebase CLI](https://firebase.google.com/docs/cli).

```sh
flutter pub get
flutter run
```

To deploy the Firestore security rules:

```sh
firebase deploy --only firestore:rules
```

### Make someone staff

In the Firebase console, set `users/{uid}.role` to `admin`. **Kitchen mode** then appears on that person's profile screen.

### Not connected yet

Online payment (Billplz) and live Lalamove bookings aren't connected. Staff can store the keys under **More > Payments & delivery APIs**, but the app doesn't call either service. Their secret keys can't live in the customer app, so a server such as Firebase Cloud Functions has to make those calls.

## Tests and screenshots

```sh
flutter test                                    # run the tests in test/
flutter test test_preview --update-goldens      # regenerate the screenshots
```

Screenshots are saved to `test_preview/shots/`, so the images in this README update when you regenerate them.

## Project layout

```text
lib/
  models/     Products, orders, refunds and shop data
  screens/    shop/ (customers), admin/ (kitchen mode), auth/
  services/   Auth, cart, Firestore repository, sample data
  widgets/    Shared UI
  theme.dart  App designs and the kitchen theme
tool/         One-time import from the old website's database
test_preview/ Screenshot generator and output
```
