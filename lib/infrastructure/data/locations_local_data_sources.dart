import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diary/domain/entities/call_to_action_response.dart';
import 'package:diary/domain/entities/location.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../database.dart' as db;

abstract class LocationsLocalDataSources {
  Future<List<Location>> getAllLocations();
  Future<List<Location>> getLocationsBetween(DateTime start, DateTime end);
  Future saveNewCallToActionResult(Call call);
  Future updateCall(Call call);
  List<Call> getAllCalls();
  Future deleteCall(Call call);
}

List<Location> buildLocations(List<Map<String, dynamic>> list) {
  try {
    final locations = list
        .map<Location>(
          (dbLoc) => Location.fromJson(
            json.decode(
              String.fromCharCodes(dbLoc['data']),
            ),
          ),
        )
        .toList();
    return locations;
  } catch (e) {
    print(e);
    return [];
  }
}

class LocationsLocalDataSourcesImpl implements LocationsLocalDataSources {
  Box<Call> box;

  LocationsLocalDataSourcesImpl() {
    box = Hive.box('calls');
  }

  // AsyncThread
//  @override
//  Future<List<Location>> getAllLocations() async {
//    final List<Map<String, dynamic>> list =
//        await db.DiAryDatabase.get().getAllLocations();
//    final locations = await compute<List<Map<String, dynamic>>, List<Location>>(
//        buildLocations, list);
//    return locations;
//  }

  @override
  Future<List<Location>> getAllLocations() async {
    final List<Map<String, dynamic>> list =
        await db.DiAryDatabase.get().getAllLocations();
    final locations = list
        .map(
          (dbLoc) => Location.fromJson(
            json.decode(
              String.fromCharCodes(dbLoc['data']),
            ),
          ),
        )
        .toList();
    return locations;
  }

  //2020-09-07T11:00:00.000Z
  //2020-09-07T13:00:00.000Z
  @override
  Future<List<Location>> getLocationsBetween(
      DateTime start, DateTime end) async {
    String fromString;
    String toString;
    if (Platform.isAndroid) {
      fromString = start.toIso8601String();
      toString = end.toIso8601String();
    } else if (Platform.isIOS) {
      fromString = (start.millisecondsSinceEpoch / 1000).toString();
      toString = (end.millisecondsSinceEpoch / 1000).toString();
    }

    final List<Map<String, dynamic>> list =
        await db.DiAryDatabase.get().getLocationsBetween(fromString, toString);
    final locations = await compute<List<Map<String, dynamic>>, List<Location>>(
        buildLocations, list);
    return locations;
  }

  @override
  Future saveNewCallToActionResult(Call call) async {
    call.insertedDate = DateTime.now();
    await box.put(call.id, call);
  }

  @override
  Future updateCall(Call call) async {
    await box.put(call.id, call);
  }

  @override
  List<Call> getAllCalls() {
    final list = box.values.toList();
    if (list.isNotEmpty) {
      list.sort((a, b) => (b.insertedDate ?? DateTime.now())
          .compareTo(a.insertedDate ?? DateTime.now()));
    }
    return list;
  }

  @override
  Future deleteCall(Call call) async {
    await box.delete(call.id);
  }
}
