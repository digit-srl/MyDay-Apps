import 'package:dartz/dartz.dart';
import 'package:diary/core/errors/failures.dart';
import 'package:diary/domain/entities/call_to_action.dart';
import 'package:diary/domain/entities/call_to_action_response.dart';
import 'package:diary/domain/entities/call_to_action_source.dart';
import 'package:diary/domain/entities/day.dart';
import 'package:diary/domain/entities/location.dart';
import 'package:diary/infrastructure/data/call_to_action_remote_data_sources.dart';
import 'package:diary/infrastructure/data/locations_local_data_sources.dart';
import 'package:diary/utils/extensions.dart';
import 'package:diary/utils/location_utils.dart';
import 'package:diary/utils/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:geodesy/geodesy.dart';
import 'package:hive/hive.dart';
import '../../database.dart' as db;

abstract class LocationRepository {
  Future<Either<Failure, List<Location>>> getAllLocations();
  Future<Either<Failure, List<Location>>> getLocationsBetween(
      DateTime start, DateTime end);
  Future<Map<DateTime, List<Location>>> readAndFilterLocationsPerDay();
  Future<Either<Failure, List<Call>>> performCallToAction(
      DateTime lastCallToAction);
  Either<Failure, List<Call>> getAllCalls();

  Future updateCall(Call call);
  Future deleteCall(Call call);
}

class LocationRepositoryImpl implements LocationRepository {
  final LocationsLocalDataSources locationsLocalDataSources;
  final CallToActionRemoteDataSources callToActionRemoteDataSources;
  LocationRepositoryImpl(
      this.locationsLocalDataSources, this.callToActionRemoteDataSources);

  @override
  Future<Either<Failure, List<Location>>> getAllLocations() async {
    try {
      final locations = await locationsLocalDataSources.getAllLocations();
      return right(locations);
    } catch (e) {
      logger.e(e);
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Location>>> getLocationsBetween(
      DateTime start, DateTime end) async {
    try {
      final locations =
          await locationsLocalDataSources.getLocationsBetween(start, end);
      return right(locations);
    } catch (e) {
      logger.e(e);
      return left(UnknownFailure(e.toString()));
    }
  }

  Future<Map<DateTime, List<Location>>> readAndFilterLocationsPerDay() async {
    final locationsPerDay = <DateTime, List<Location>>{};
    try {
      final locations = await locationsLocalDataSources.getAllLocations();
      logger.i('[LocationUtils] total records: ${locations.length}');
      final DateTime today = DateTime.now().midnight;
      if (locations.isEmpty) {
        return {today: []};
      }
      for (var loc in locations) {
        try {
          final date = loc.dateTime.midnight;
          if (!locationsPerDay.containsKey(date)) {
            locationsPerDay[date] = [];
          }
          locationsPerDay[date].add(loc);
        } catch (ex) {
          logger.e('[ERROR] _readLocations $ex');
          Hive.box<String>('logs')
              .add('[ERROR] readAndFilterLocationsPerDay $ex');
        }
      }
      logger.i('Locations from DB: ${locations.length}');
    } catch (ex, stackTrace) {
      print(ex);
      Crashlytics.instance.recordError(ex, stackTrace);
    }
    return locationsPerDay;
  }

  Future<Map<DateTime, Day>> getLocationsPerDate() async {
    final locationsPerDate = await readAndFilterLocationsPerDay();
    final days = LocationUtils.aggregateLocationsInDayPerDate(locationsPerDate);
    return days;
  }

  //  Memorizza sull app l ultima sync
//  memorizza data ultima richiesta call to action per averne solo incrementali
//  se va a buon fine aggiorno la data a quella corrente
//  call to action nome dove ci troviamo
//
//  Data
//  Lista di geohashtroncati

//  bool isLocationsInPolygon(List<Location> locations, List<LatLng> polygon) {
//    Geodesy geo = Geodesy();
//    bool result = false;
//    for (int i = 0; i < locations.length; i++) {
//      if (locations[i].isGoodPoint) {
//        final latLng =
//            LatLng(locations[i].coords.latitude, locations[i].coords.longitude);
//        result = geo.isGeoPointInPolygon(latLng, polygon);
//        if (result) {
//          break;
//        }
//      }
//    }
//    return result;
//  }

  int isLocationsInPolygon2(List<Location> locations, List<LatLng> polygon,
      int maxTime, int counter) {
    Geodesy geo = Geodesy();
    bool result = false;
    DateTime lastTimestamp;
    int output = 0 + counter;
    for (int i = 0; i < locations.length; i++) {
      if (locations[i].isGoodPoint) {
        if (result) {
          output += locations[i].dateTime.difference(lastTimestamp).inSeconds;
          result = false;
          if (output >= maxTime) {
            logger.i('stop locations cycle');
            logger.i('partial time : $output');
            break;
          }
        }

        final latLng =
            LatLng(locations[i].coords.latitude, locations[i].coords.longitude);
        result = geo.isGeoPointInPolygon(latLng, polygon);
        lastTimestamp = locations[i].dateTime;
      }
    }
    return output == counter ? null : output;
  }

/*  @override
  Future<Either<Failure, CallToAction>> builregegege() async {
    try {
      final map = <DateTime, Set<String>>{};
      CallToAction callToAction = CallToAction(
          lastCheckTimestamp: DateTime.now().toUtc(), activities: []);
      final result = await getAllLocations();
      final locations = result.getOrElse(() => []);
      for (int i = 0; i < locations.length; i++) {
        final loc = locations[i];
        final date = loc.dateTime.isUtc
            ? loc.dateTime.midnight
            : loc.dateTime.midnight.toUtc();
        if (!map.containsKey(date)) {
          map[date] = {};
        }
        final geohash = LocationUtils.getGeohash(
            loc.coords.latitude, loc.coords.longitude,
            precision: 4);
        map[date].add(geohash);
      }

      map.forEach((k, v) {
        callToAction.activities.add(DailyHash(date: k, hashes: v.toList()));
      });

      return right(callToAction);
    } catch (e) {
      logger.e(e);
      return left(UnknownFailure(e.toString()));
    }
  }*/

  @override
  Future<Either<Failure, List<Call>>> performCallToAction(
      DateTime lastCallToAction) async {
    try {
      final result = await getAllLocations();
      final locations = List<Location>.unmodifiable(
          result.getOrElse(() => []).where((l) => l.isGoodPoint));
      if (locations.isEmpty) {
        return left(NoLocationsFoundFailure());
      }

      final callToAction = buildCallToAction(locations, lastCallToAction);
      final response =
          await callToActionRemoteDataSources.sendData(callToAction);
      final calls = await processCallToActionResponse2(response);
      for (int i = 0; i < calls.length; i++) {
        await locationsLocalDataSources.saveNewCallToActionResult(calls[i]);
      }
      return right(locationsLocalDataSources.getAllCalls());
    } catch (e) {
      logger.e(e);
      return left(UnknownFailure(e.toString()));
    }
  }

  CallToAction buildCallToAction(
      List<Location> locations, DateTime lastCallToActionDate) {
    final map = <DateTime, Set<String>>{};
    final callToAction = CallToAction(
      lastCheckTimestamp: lastCallToActionDate,
      activities: [],
    );
    for (int i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final date = loc.dateTime.midnight;
      print(date);
      if (!map.containsKey(date)) {
        map[date] = {};
      }
      final geohash = LocationUtils.getGeohash(
          loc.coords.latitude, loc.coords.longitude,
          precision: 4);
      map[date].add(geohash);
    }

    map.forEach((k, v) {
      callToAction.activities.add(DailyHash(date: k, hashes: v.toList()));
    });

    return callToAction;
  }

//  List<Call> processCallToActionResponse(
//      CallToActionResponse response, List<Location> locations) {
//    final blackList = Hive.box<CallToActionSource>('blackList').values.toList();
//    final resultCalls = <Call>[];
//    if (response.hasMatch) {
//      final calls = response.calls;
//
//      for (int k = 0; k < calls.length; k++) {
//        final call = calls[k];
//        final source = call.source;
//        if (source != null &&
//            blackList.where((c) => c.source == source).isNotEmpty) {
//          continue;
//        }
//        bool hasMatch = false;
//        for (int i = 0; i < call.queries.length && !hasMatch; i++) {
//          final q = call.queries[i];
//          final coords = q.geometry.coordinates;
//          hasMatch = isLocationsInPolygon(locations, coords);
//        }
//        if (hasMatch) {
//          resultCalls.add(call);
//          continue;
//        }
//      }
//    }
//    return resultCalls;
//  }

  Future<List<Call>> processCallToActionResponse2(
      CallToActionResponse response) async {
    final blackList = Hive.box<CallToActionSource>('blackList').values.toList();
    final resultCalls = <Call>[];
    if (response.hasMatch) {
      final calls = response.calls;

      for (int k = 0; k < calls.length; k++) {
        final call = calls[k];
        final maxTime = call.maxTime ?? 0;
        logger.i('maxTime = $maxTime');
        final source = call.source;
        if (source != null &&
            blackList.where((c) => c.source == source).isNotEmpty) {
          continue;
        }
        int partialTime = 0;
        for (int i = 0; i < call.queries.length; i++) {
          final q = call.queries[i];
          final locations =
              await locationsLocalDataSources.getLocationsBetween(q.from, q.to);
          if (locations.isEmpty) {
            continue;
          }
          final coords = q.geometry.coordinates;
          final result =
              isLocationsInPolygon2(locations, coords, maxTime, partialTime);
          if (result != null) {
            partialTime = result;
          } else {
            continue;
          }
          logger.i('partialTime = $partialTime');
          if (partialTime >= maxTime) {
            logger.i('stop query cycle');
            logger.i('matching');
            resultCalls.add(call);
            break;
          }
        }
        if (partialTime >= maxTime) {
          logger.i('go to next call');
          continue;
        }
      }
    }
    return resultCalls;
  }

  @override
  Either<Failure, List<Call>> getAllCalls() {
    try {
      final calls = locationsLocalDataSources.getAllCalls();
//      if (calls.isEmpty) return left(NoCallsFoundFailure());
      return right(calls);
    } catch (e) {
      logger.e(e);
      return left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future updateCall(Call call) async {
    await locationsLocalDataSources.updateCall(call);
  }

  @override
  Future deleteCall(Call call) async {
    await locationsLocalDataSources.deleteCall(call);
  }
}

final fakeCallActionResponse = """ 
{
	"hasMatch": true,
	"calls": [{
		"id": "5ea685ee8095c8174005f558",
		"description": "Call to action di prova",
		"url": "https://www.example.org",
		"queries": [
			{
				"from": "2020-04-26T09:30:00Z",
				"to": "2020-04-26T21:00:00Z",
				"geometry": {
					"type": "Polygon",
					"coordinates": [
          [
            [
              13.713083267211914,
              42.82241369816499
            ],
            [
              13.704371452331543,
              42.815205076860195
            ],
            [
              13.714971542358398,
              42.809412387958666
            ],
            [
              13.732137680053711,
              42.81026243605641
            ],
            [
              13.733940124511719,
              42.818038259708736
            ],
            [
              13.729004859924316,
              42.8245540876428
            ],
            [
              13.713040351867676,
              42.82392456901815
            ],
            [
              13.713083267211914,
              42.82241369816499
            ]
          ]
        ]
				}
			},
			{
				"from": "2020-04-27T09:30:00Z",
				"to": "2020-04-27T21:00:00Z",
				"geometry": {
					"type": "Polygon",
					"coordinates": [
          [
            [
              12.632946968078613,
              43.72915023199818
            ],
            [
              12.633204460144043,
              43.722079239349036
            ],
            [
              12.636551856994629,
              43.718605463566874
            ],
            [
              12.642302513122559,
              43.7199081530876
            ],
            [
              12.64221668243408,
              43.72797179118628
            ],
            [
              12.637495994567871,
              43.73026662822251
            ],
            [
              12.632946968078613,
              43.72915023199818
            ]
          ]
        ]
				}
			},
		]
	}]
}
""";
