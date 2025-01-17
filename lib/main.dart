import 'dart:async';
import 'dart:io';
import 'package:meta_seo/meta_seo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart/controller/auth_controller.dart';
import 'package:sixam_mart/controller/cart_controller.dart';
import 'package:sixam_mart/controller/localization_controller.dart';
import 'package:sixam_mart/controller/location_controller.dart';
import 'package:sixam_mart/controller/splash_controller.dart';
import 'package:sixam_mart/controller/theme_controller.dart';
import 'package:sixam_mart/controller/wishlist_controller.dart';
import 'package:sixam_mart/data/model/body/notification_body.dart';
import 'package:sixam_mart/helper/notification_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/theme/dark_theme.dart';
import 'package:sixam_mart/theme/light_theme.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/view/screens/home/widget/cookies_view.dart';
import 'package:url_strategy/url_strategy.dart';
import 'data/api/api_checker.dart';
import 'data/api/api_client.dart';
import 'data/repository/splash_repo.dart';
import 'helper/get_di.dart' as di;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences and ApiClient
  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  ApiClient apiClient = ApiClient(appBaseUrl: "", sharedPreferences: sharedPreferences);


  // Ensure SplashRepo is initialized
  SplashRepo splashRepo = SplashRepo(sharedPreferences: sharedPreferences, apiClient: apiClient);


  // Register SplashController with the initialized SplashRepo
  Get.put(SplashController(splashRepo: splashRepo));

  if (ResponsiveHelper.isMobilePhone()) {
    HttpOverrides.global = MyHttpOverrides();
  }

  setPathUrlStrategy();

  try {
    await Firebase.initializeApp(
      options: GetPlatform.isWeb
          ? const FirebaseOptions(
              apiKey: "AIzaSyBa7rtEddUrKnvDV0ekNa6RkWOozvB2yoc",
              authDomain: "mecan-db9f9.firebaseapp.com",
              projectId: "mecan-db9f9",
              storageBucket: "mecan-db9f9.appspot.com",
              messagingSenderId: "41720817871",
              appId: "1:41720817871:web:e376f44b9e6853ed85afba",
              measurementId: "G-KDEJ4P89TT",
            )
          : null,
    );

    if (GetPlatform.isWeb) {
      MetaSEO().config();
    }

    Map<String, Map<String, String>> languages = await di.init();
    NotificationBody? body;

    if (GetPlatform.isMobile) {
      final RemoteMessage? remoteMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (remoteMessage != null) {
        body = NotificationHelper.convertNotification(remoteMessage.data);
      }
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    }

    runApp(MyApp(languages: languages, body: body));
  } catch (e) {
    print("Error initializing Firebase: $e");
  }
}

class MyApp extends StatefulWidget {
  final Map<String, Map<String, String>>? languages;
  final NotificationBody? body;

  const MyApp({Key? key, required this.languages, required this.body})
      : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  void _route() async {
    if (GetPlatform.isWeb) {
      await Get.find<SplashController>().initSharedData();
      if (Get.find<LocationController>().getUserAddress() != null &&
          Get.find<LocationController>().getUserAddress()!.zoneIds == null) {
        Get.find<AuthController>().clearSharedAddress();
      }

      if (!Get.find<AuthController>().isLoggedIn() &&
          !Get.find<AuthController>().isGuestLoggedIn()) {
        await Get.find<AuthController>().guestLogin();
      }
      if ((Get.find<AuthController>().isLoggedIn() ||
              Get.find<AuthController>().isGuestLoggedIn()) &&
          Get.find<SplashController>().cacheModule != null) {
        Get.find<CartController>().getCartDataOnline();
      }
    }
    Get.find<SplashController>()
        .getConfigData(loadLandingData: GetPlatform.isWeb)
        .then((bool isSuccess) async {
      if (isSuccess) {
        if (Get.find<AuthController>().isLoggedIn()) {
          Get.find<AuthController>().updateToken();
          if (Get.find<SplashController>().module != null) {
            await Get.find<WishListController>().getWishList();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(builder: (themeController) {
      return GetBuilder<LocalizationController>(builder: (localizeController) {
        return GetBuilder<SplashController>(builder: (splashController) {
          return (GetPlatform.isWeb && splashController.configModel == null)
              ? const SizedBox()
              : GetMaterialApp(
                  title: AppConstants.appName,
                  debugShowCheckedModeBanner: false,
                  navigatorKey: Get.key,
                  scrollBehavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch
                    },
                  ),
                  theme: themeController.darkTheme ? dark() : light(),
                  locale: localizeController.locale,
                  translations: Messages(languages: widget.languages),
                  fallbackLocale: Locale(
                      AppConstants.languages[0].languageCode!,
                      AppConstants.languages[0].countryCode),
                  initialRoute: GetPlatform.isWeb
                      ? RouteHelper.getInitialRoute()
                      : RouteHelper.getSplashRoute(widget.body),
                  getPages: RouteHelper.routes,
                  defaultTransition: Transition.topLevel,
                  transitionDuration: const Duration(milliseconds: 500),
                  builder: (BuildContext context, widget) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
                      child: Material(
                          child: Stack(children: [
                        widget!,
                        GetBuilder<SplashController>(
                            builder: (splashController) {
                          if (!splashController.savedCookiesData &&
                              !splashController.getAcceptCookiesStatus(
                                  splashController.configModel != null
                                      ? splashController
                                          .configModel!.cookiesText!
                                      : '')) {
                            return ResponsiveHelper.isWeb()
                                ? const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: CookiesView())
                                : const SizedBox();
                          } else {
                            return const SizedBox();
                          }
                        })
                      ])),
                    );
                  },
                );
        });
      });
    });
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  // Handle background message
  print("Background message: ${message.notification?.title}");
}
