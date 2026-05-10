# another_flushbar

[![Pub Version](https://img.shields.io/pub/v/another_flushbar.svg?style=flat-square)](https://pub.dartlang.org/packages/another_flushbar)
[![Pub Likes](https://img.shields.io/pub/likes/another_flushbar?style=flat-square)](https://pub.dev/packages/another_flushbar)
[![Pub Points](https://img.shields.io/pub/points/another_flushbar?style=flat-square)](https://pub.dev/packages/another_flushbar)

A highly customizable Flutter notification bar for Android and iOS.  
More flexible than a SnackBar. More native than a Toast.

---

## 🚀 New in v2.0.0 — Remote notifications via FlushKit

Trigger Flushbar notifications **from your server** — without rebuilding or redeploying your app.

```dart
// One line in your app
FlushbarRemote.init(
  apiKey: 'fk_live_••••••••',
  context: context,
);
```

```bash
# Trigger from anywhere — your backend, a cron job, or curl
curl -X POST https://api.flushkit.dev/v1/notify \
  -H "Authorization: Bearer fk_live_••••••••" \
  -H "Content-Type: application/json" \
  -d '{"message": "Order shipped!", "position": "top"}'
```

**[Get a free API key at flushkit.dev →](https://flushkit.dev)**

- ✅ Real-time delivery via SSE — under 100ms
- ✅ Full Flushbar control — color, position, duration, title
- ✅ Works on Android, iOS, Web, Desktop
- ✅ Auto-reconnect with exponential backoff
- ✅ Battery-aware — pauses when app is backgrounded
- ✅ Free tier available — no credit card required

---

## Installation

```yaml
dependencies:
  another_flushbar: ^2.0.0
```

See full [install instructions](https://pub.dev/packages/another_flushbar/install).

---

## FlushKit — Remote Notifications

### Setup

Add `FlushbarRemote.init()` once in your root widget's `initState()`, after the first frame is built:

```dart
import 'package:another_flushbar/another_flushbar.dart';

class _RootState extends State<RootWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlushbarRemote.init(
        apiKey: 'fk_live_••••••••',
        context: context,
      );
    });
  }

  @override
  void dispose() {
    FlushbarRemote.dispose();
    super.dispose();
  }
}
```

### Optional: Listen to raw events

```dart
FlushbarRemote.events.listen((event) {
  debugPrint('Received: ${event.message}');
  // Custom handling in addition to automatic display
});
```

### FlushbarRemote.init — parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `apiKey` | `String` | ✅ | Your FlushKit project API key |
| `context` | `BuildContext` | ✅ | Used to show the Flushbar overlay |
| `baseUrl` | `String?` | — | Override API URL (default: `api.flushkit.dev`) |

### Listening to events

To handle events beyond the automatic Flushbar display,
listen to the events stream after calling `init()`:

```dart
FlushbarRemote.init(
apiKey: 'fk_live_••••••••',
context: context,
);

FlushbarRemote.events.listen((event) {
debugPrint('Received: ${event.message}');
analytics.track('notification_received');
});
```

### Delivery behaviour

FlushKit delivers to **active users** — devices with your app open or recently backgrounded.

| App state | Delivery |
|---|---|
| App open (foreground) | ✅ Instant |
| App backgrounded | ✅ On resume |
| App fully closed | ❌ Not delivered |

> **[Full documentation at flushkit.dev/docs →](https://flushkit.dev/docs)**

---

## Local Flushbar Usage

### Quick reference

| Property | Description |
|---|---|
| `title` | Title text |
| `titleColor` | Title color |
| `titleSize` | Title font size |
| `message` | Message text (required) |
| `messageColor` | Message color |
| `messageSize` | Message font size |
| `titleText` | Replaces `title` — accepts any widget |
| `messageText` | Replaces `message` — accepts any widget |
| `icon` | Widget shown on the left (Icon or Image recommended) |
| `shouldIconPulse` | Animate the icon. Default: `true` |
| `maxWidth` | Limit Flushbar width on large screens |
| `margin` | Custom margin |
| `padding` | Custom padding |
| `borderRadius` | Corner radius (best with `margin`) |
| `textDirection` | LTR/RTL. Use `Directionality.of(context)` for RTL |
| `borderColor` | Border color |
| `borderWidth` | Border width |
| `backgroundColor` | Background color (ignored if `backgroundGradient` set) |
| `backgroundGradient` | Background gradient |
| `leftBarIndicatorColor` | Colored left bar indicator |
| `boxShadows` | Custom shadows |
| `mainButton` | Action button (TextButton recommended) |
| `onTap` | Tap callback (alternative to `mainButton`) |
| `duration` | Auto-dismiss duration. `null` = infinite |
| `isDismissible` | Allow swipe to dismiss. Default: `true` |
| `dismissDirection` | VERTICAL (default) or HORIZONTAL |
| `flushbarPosition` | TOP or BOTTOM (default) |
| `flushbarStyle` | FLOATING (default) or GROUNDED |
| `forwardAnimationCurve` | Show animation curve. Default: `Curves.easeOut` |
| `reverseAnimationCurve` | Dismiss animation curve. Default: `Curves.fastOutSlowIn` |
| `animationDuration` | Animation speed |
| `showProgressIndicator` | Show a LinearProgressIndicator |
| `progressIndicatorController` | Control progress manually |
| `progressIndicatorBackgroundColor` | Progress bar background |
| `progressIndicatorValueColor` | Progress bar value color |
| `barBlur` | Blur Flushbar background. Default: `0.0` |
| `blockBackgroundInteraction` | Block interaction behind Flushbar |
| `routeBlur` | Blur overlay behind Flushbar |
| `routeColor` | Overlay color (requires `routeBlur > 0`) |
| `userInputForm` | Embed a TextFormField |
| `onStatusChanged` | Status change callback |

> **Tip:** Use `FlushbarHelper` for common patterns — success, error, info, loading.

---

### A basic Flushbar

```dart
Flushbar(
  title: "Hey Ninja",
  message: "Lorem Ipsum is simply dummy text of the printing and typesetting industry",
  duration: Duration(seconds: 3),
)..show(context);
```

![Basic Example](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/basic_bar.png)

---

### Fully customized

```dart
Flushbar(
  title: "Hey Ninja",
  titleColor: Colors.white,
  message: "Lorem Ipsum is simply dummy text of the printing and typesetting industry",
  flushbarPosition: FlushbarPosition.TOP,
  flushbarStyle: FlushbarStyle.FLOATING,
  reverseAnimationCurve: Curves.decelerate,
  forwardAnimationCurve: Curves.elasticOut,
  backgroundColor: Colors.red,
  boxShadows: [BoxShadow(color: Colors.blue[800]!, offset: Offset(0.0, 2.0), blurRadius: 3.0)],
  backgroundGradient: LinearGradient(colors: [Colors.blueGrey, Colors.black]),
  isDismissible: false,
  duration: Duration(seconds: 4),
  icon: Icon(Icons.check, color: Colors.greenAccent),
  mainButton: TextButton(
    onPressed: () {},
    child: Text("CLAP", style: TextStyle(color: Colors.amber)),
  ),
  showProgressIndicator: true,
  progressIndicatorBackgroundColor: Colors.blueGrey,
  titleText: Text(
    "Hello Hero",
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20.0,
      color: Colors.yellow[600],
      fontFamily: "ShadowsIntoLightTwo",
    ),
  ),
  messageText: Text(
    "You killed that giant monster in the city. Congratulations!",
    style: TextStyle(fontSize: 18.0, color: Colors.green, fontFamily: "ShadowsIntoLightTwo"),
  ),
)..show(context);
```

![Complete Example](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/complete_bar.png)

---

### Styles

```dart
Flushbar(flushbarStyle: FlushbarStyle.FLOATING) // default
Flushbar(flushbarStyle: FlushbarStyle.GROUNDED)
```

Floating Style | Grounded Style
:---:|:---:
![Floating](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/floating_style.png) | ![Grounded](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/grounded_style.png)

---

### Padding and border radius

```dart
Flushbar(
  margin: EdgeInsets.all(8),
  borderRadius: BorderRadius.circular(8),
)..show(context);
```

![Padding and Radius](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/padding_and_radius.png)

---

### Left indicator bar

```dart
Flushbar(
  message: "Lorem Ipsum is simply dummy text",
  icon: Icon(Icons.info_outline, size: 28.0, color: Colors.blue[300]),
  duration: Duration(seconds: 3),
  leftBarIndicatorColor: Colors.blue[300],
)..show(context);
```

![Left Indicator](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/left_bar_indicator.png)

---

### Custom text

```dart
Flushbar(
  titleText: Text(
    "Hello Hero",
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20.0,
      color: Colors.yellow[600],
      fontFamily: "ShadowsIntoLightTwo",
    ),
  ),
  messageText: Text(
    "You killed that giant monster in the city. Congratulations!",
    style: TextStyle(fontSize: 16.0, color: Colors.green, fontFamily: "ShadowsIntoLightTwo"),
  ),
)..show(context);
```

![Custom Text](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/text_bar.png)

---

### Background color and gradient

```dart
// Solid color
Flushbar(
  title: "Hey Ninja",
  message: "Lorem Ipsum",
  backgroundColor: Colors.red,
  boxShadows: [BoxShadow(color: Colors.red[800]!, offset: Offset(0.0, 2.0), blurRadius: 3.0)],
)..show(context);

// Gradient
Flushbar(
  title: "Hey Ninja",
  message: "Lorem Ipsum",
  backgroundGradient: LinearGradient(colors: [Colors.blue, Colors.teal]),
  boxShadows: [BoxShadow(color: Colors.blue[800]!, offset: Offset(0.0, 2.0), blurRadius: 3.0)],
)..show(context);
```

![Background Color](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/background_color_bar.png)
![Gradient](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/gradient_bar.png)

---

### Icon and button

```dart
Flushbar<bool>(
  title: "Hey Ninja",
  message: "Lorem Ipsum is simply dummy text",
  icon: Icon(Icons.info_outline, color: Colors.blue),
  mainButton: TextButton(
    onPressed: () => flush.dismiss(true),
    child: Text("ADD", style: TextStyle(color: Colors.amber)),
  ),
)..show(context).then((result) {
  // result = true if button tapped
});
```

![Icon and Button](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/icon_and_button_bar.png)

---

### Position

```dart
Flushbar(
  flushbarPosition: FlushbarPosition.TOP,
  title: "Hey Ninja",
  message: "Lorem Ipsum",
)..show(context);
```

![Position](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/position_bar.png)

---

### Progress indicator

```dart
AnimationController _controller = AnimationController(
  vsync: this,
  duration: Duration(seconds: 3),
);

Flushbar(
  title: "Hey Ninja",
  message: "Loading...",
  showProgressIndicator: true,
  progressIndicatorController: _controller,
  progressIndicatorBackgroundColor: Colors.grey[800],
)..show(context);
```

---

### Status listener

```dart
Flushbar(
  title: "Hey Ninja",
  message: "Lorem Ipsum",
)
  ..onStatusChanged = (FlushbarStatus status) {
    switch (status) {
      case FlushbarStatus.SHOWING:     doSomething(); break;
      case FlushbarStatus.IS_APPEARING: doSomethingElse(); break;
      case FlushbarStatus.IS_HIDING:   doSomethingElse(); break;
      case FlushbarStatus.DISMISSED:   doSomethingElse(); break;
    }
  }
  ..show(context);
```

---

### RTL support

```dart
Flushbar(
  message: "لوريم إيبسوم هو ببساطة نص شكلي",
  icon: Icon(Icons.info_outline, size: 28.0, color: Colors.blue[300]),
  margin: EdgeInsets.all(6.0),
  flushbarStyle: FlushbarStyle.FLOATING,
  flushbarPosition: FlushbarPosition.TOP,
  textDirection: Directionality.of(context),
  borderRadius: BorderRadius.circular(12),
  duration: Duration(seconds: 3),
  leftBarIndicatorColor: Colors.blue[300],
)..show(context);
```

![RTL](https://github.com/cmdrootaccess/another-flushbar/raw/main/readme_resources/rtl_bar.png)

---

## FlushbarHelper

Shortcut factory methods for common notification types:

```dart
FlushbarHelper.createSuccess(message: "Done!", title: "Success");
FlushbarHelper.createError(message: "Something went wrong", title: "Error");
FlushbarHelper.createInformation(message: "FYI...", title: "Info");
FlushbarHelper.createLoading(message: "Please wait...");
FlushbarHelper.createAction(message: "Undo?", title: "Deleted", flatButton: undoButton);
FlushbarHelper.createInputFlushbar(textForm: myForm);
```

---

## Video tutorials

1. [Beginner tutorial](https://www.youtube.com/watch?v=KNpxyyA8MDA) by **Matej Rešetár**
2. [Advanced usage](https://www.youtube.com/watch?v=FRCvqkyeCzQ) by **Javier González Rodríguez**

---

## Links

- 📦 [pub.dev](https://pub.dev/packages/another_flushbar)
- 🔔 [FlushKit — remote notifications](https://flushkit.dev)
- 📖 [FlushKit docs](https://flushkit.dev/docs)
- 🐛 [GitHub issues](https://github.com/cmdrootaccess/another-flushbar/issues)
