import 'package:diary/domain/entities/daily_stats_response.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diary/utils/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app.dart';
import 'package:diary/utils/extensions.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'domain/entities/annotation.dart';
import 'domain/entities/day.dart';
import 'domain/entities/location.dart';
import 'domain/entities/place.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

BitmapDescriptor currentPositionMarkerIcon;
BitmapDescriptor annotationPositionMarkerIcon;
BitmapDescriptor pinPositionMarkerIcon;
BitmapDescriptor selectedPinMarkerIcon;
BitmapDescriptor genericPinMarkerIcon;

FirebaseAnalytics analytics = FirebaseAnalytics();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set `enableInDevMode` to true to see reports while in debug mode
  // This is only to be used for confirming that reports are being
  // submitted as expected. It is not intended to be used for everyday
  // development.
//  Crashlytics.instance.enableInDevMode = true;

  // Pass all uncaught errors from the framework to Crashlytics.
  FlutterError.onError = Crashlytics.instance.recordFlutterError;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      //ANDROID
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      //iOS
      statusBarBrightness: Brightness.light,
    ),
  );

//  final List<bg.Location> locations = List<bg.Location>.unmodifiable(
//      (await bg.BackgroundGeolocation.locations)
//          .map((map) => bg.Location(map))
//          .toList());

//  final today = DateTime.now().withoutMinAndSec();
//  final todayDate = Day(
//    date: today,
//    slices: [
//      Slice(
//        minutes: 570,
//        startTime: today,
//
//        activity: MotionActivity.Still,
//      ),
//      Slice(
//        minutes: 1440 - 570,
//        startTime: today.copyWith(hour: 9, minute: 30),
//
//        activity: MotionActivity.Unknown,
//      ),
//    ],
//    notes: [
//      Note(
//        id: '2',
//        dateTime: DateTime.now().subtract(Duration(hours: 2)),
//      ),
//      Note(
//        id: '1',
//        dateTime: DateTime.now(),
//      ),
//      Note(
//        id: '3',
//        dateTime: DateTime.now().add(Duration(hours: 2)),
//      ),
//    ],
//    pointCount: 2,
//  );
//  final fakeTodayDate =  <DateTime, Day>{
//    today: todayDate,
//  };

  await Hive.initFlutter();
  Hive.registerAdapter(AnnotationAdapter());
  Hive.registerAdapter(PlaceAdapter());
  Hive.registerAdapter(DailyStatsResponseAdapter());
  await Hive.openBox<String>('logs');
  await Hive.openBox('user');
  await Hive.openBox<Annotation>('annotations');
  await Hive.openBox('dailyStatsResponse');
  await Hive.openBox<Place>('places');
  await Hive.openBox<String>('pinNotes');
  final Map<DateTime, List<Location>> locationsPerDate =
      await LocationUtils.readAndFilterLocationsPerDay();
  final days = LocationUtils.aggregateLocationsInDayPerDate(locationsPerDate);

  final today = DateTime.now().withoutMinAndSec();
  if (!days.containsKey(today)) {
    days[today] = Day(date: today);
  }

  runApp(
    MyDayApp(locationsPerDate: locationsPerDate, days: days),
//    DevicePreview(
//      enabled: !kReleaseMode,
//      builder: (context) =>
//          MyDayApp(locationsPerDate: locationsPerDate, days: days),
//    ),
  );
}
