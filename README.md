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
- **AI insights:** revenue and sales forecasts for the next 7, 14 or 30 days, a trend report on what is selling more or less, and an optional written summary

### AI insights

The forecasts and trend report are worked out inside the app from the last 180 days of orders, so they need no setup. A forecast appears once there are at least 14 days of history with sales on 5 or more of them.

The written summary comes from [Ollama](https://ollama.com), which runs an AI model on the shop's own computer. No sales data goes to an outside AI service. The app picks the first installed model from `phi3:mini`, `qwen2.5-coder:1.5b` and `llama3.2:1b`, and you can change it on the screen.

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

## Built with

- **Flutter** for the app on Android, iOS, web and desktop
- **Firebase Authentication** for sign-in and **Cloud Firestore** for products, orders, refunds and shop settings
- **Provider** for app state, **shared_preferences** for settings saved on the device and **Google Fonts** for the app designs
- **Ollama** (optional) for the AI written summary, running on the shop's own computer

## Getting started

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart 3.13.7 or newer. To deploy database rules, you also need the [Firebase CLI](https://firebase.google.com/docs/cli).

```sh
flutter pub get
flutter run
```

To choose where the app runs, list the devices and pass one with `-d`:

```sh
flutter devices                 # phones, Chrome, Windows...
flutter run -d chrome           # in the browser
flutter run -d windows          # as a Windows app
flutter run -d <device id>      # on a USB-connected phone
```

The first run on a phone can take 3 to 10 minutes. While it runs, press `r` to hot reload, `R` to restart and `q` to stop.

To build an Android app you can install on any phone:

```sh
flutter build apk --release
```

The file is saved to `build/app/outputs/flutter-apk/app-release.apk`.

To deploy the Firestore security rules:

```sh
firebase deploy --only firestore:rules
```

### Make someone staff

In the Firebase console, set `users/{uid}.role` to `admin`. **Kitchen mode** then appears on that person's profile screen.

### Turn on the AI summary (optional)

1. Install [Ollama](https://ollama.com) and download a model once:

   ```sh
   ollama pull phi3:mini
   ```

2. **Chrome or Windows on the same computer:** nothing else to do. The app uses `http://localhost:11434`.

3. **Android phone:** plug it in by USB with USB debugging on, then run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\run_phone.ps1
   ```

   The script starts Ollama if it isn't running, runs `adb reverse tcp:11434 tcp:11434` so the phone reaches Ollama through the cable, then starts the app. It works without Wi-Fi, including on a mobile hotspot.

To use another computer, tap the gear icon on the **AI insights** screen and enter its address, for example `http://192.168.1.10:11434`. That computer needs `OLLAMA_HOST=0.0.0.0` set and Ollama allowed through its firewall.

[HOW_TO_RUN.txt](HOW_TO_RUN.txt) has a step-by-step guide and fixes for common errors.

### Copy data from the old website

`tool/import_website_data.py` copies customers, orders, refunds and reviews from the old Laravel website's MySQL database into Firebase. It never copies passwords and never overwrites orders made in the app. When a customer signs up in the app with the same email and verifies it, their website orders and refunds move to the new account.

Start MySQL (for example in Laragon) and run `firebase login` first, then:

```sh
python tool/import_website_data.py            # preview what would be copied
python tool/import_website_data.py --write    # copy it into Firebase
```

### Not connected yet

Online payment (Billplz) and live Lalamove bookings aren't connected. Staff can store the keys under **More > Payments & delivery APIs**, but the app doesn't call either service. Their secret keys can't live in the customer app, so a server such as Firebase Cloud Functions has to make those calls.

## Python version of the AI

`ai_python/` has the same sales forecast and Ollama client as the app, written in Python with only the standard library. It gives the same numbers as the app for the same orders, so you can check or reuse the forecasts outside Flutter.

```python
from datetime import datetime, timedelta
from sales_forecast import ShopOrder, OrderItem, SalesHistory, Forecast, TrendReport

now = datetime.now()
orders = [
    ShopOrder(created_at=now - timedelta(days=d), total=40 + d % 7 * 5, items=[OrderItem('Egg tart', 3)])
    for d in range(1, 30)
]

history = SalesHistory.from_orders(orders, now)
forecast = Forecast.compute(history.revenue, history.first_day, 7)  # None if there isn't enough history
print(f'Next 7 days: RM{forecast.low:.2f} to RM{forecast.high:.2f} ({forecast.confidence.label} confidence)')

trend = TrendReport.from_orders(orders, now)
```

Run it from inside `ai_python/`. A forecast needs at least 14 days of history with sales on 5 or more of them. To get a written summary, pass the prompt from `build_insight_prompt(...)` to `LocalAiService().generate(model, prompt)` in `local_ai_service.py`.

## Tests and screenshots

```sh
flutter analyze                                 # check the code for problems
flutter test                                    # run the tests in test/
flutter test test_preview --update-goldens      # regenerate the screenshots
```

Screenshots are saved to `test_preview/shots/`, so the images in this README update when you regenerate them.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Phone doesn't show in `flutter devices` | Plug it in again and tap **Allow** on the phone. Try another cable (some only charge) and set the USB mode to **File transfer**. |
| Build errors or old errors that won't go away | Run `flutter clean`, then `flutter pub get` and `flutter run`. |
| "Couldn't reach the AI server" | Check that Ollama is open (llama icon in the taskbar). On a phone, run `tool\run_phone.ps1` again to redo the USB link. |
| "Ollama is running but has no models" | Run `ollama pull phi3:mini`. |
| No **Kitchen mode** on the profile screen | Set `users/{uid}.role` to `admin` in Firebase, then restart the app. |

## Project layout

```textt
lib/
  models/     Products, orders, refunds and shop data
  screens/    shop/ (customers), admin/ (kitchen mode), auth/
  services/   Auth, cart, Firestore repository, sample data,
              sales forecasts and the Ollama client
  widgets/    Shared UI
  theme.dart  App designs and the kitchen theme
ai_python/    Python versions of the sales forecast and Ollama client
tool/         Phone launcher with the AI link (run_phone.ps1) and a
              one-time import from the old website's database
test_preview/ Screenshot generator and output
```
