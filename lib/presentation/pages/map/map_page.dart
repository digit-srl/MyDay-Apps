import 'dart:async';

import 'package:diary/application/annotation_notifier.dart';
import 'package:diary/application/geofence_notifier.dart';
import 'package:diary/application/info_pin/info_pin_notifier.dart';
import 'package:diary/application/info_pin/info_pin_state.dart';
import 'package:diary/domain/entities/annotation.dart';
import 'package:diary/domain/entities/colored_geofence.dart';
import 'package:diary/domain/entities/location.dart';
import 'package:diary/presentation/pages/map/widgets/info_annotation.dart';
import 'package:diary/presentation/pages/map/widgets/info_geofence.dart';
import 'package:diary/presentation/widgets/manual_detection_position_layer.dart';
import 'package:diary/utils/app_theme.dart';
import 'package:diary/utils/bottom_sheets.dart';
import 'package:diary/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:diary/application/geofence_event_notifier.dart';
import 'package:diary/application/location_notifier.dart';
import 'package:diary/application/date_notifier.dart';
import 'package:diary/application/service_notifier.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../../../main.dart';
import 'widgets/geofence_marker.dart';
import 'package:diary/utils/extensions.dart';

import 'widgets/info_pin.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>
    with AutomaticKeepAliveClientMixin<MapPage> {
  @override
  bool get wantKeepAlive {
    return true;
  }

  static final CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  Function removeServiceListener;
  Function removeLocationListener;
  Function removeDateListener;
  Function removeGeofenceListener;
  Function removeGeofenceEventListener;
  Function removeGeofenceChangeListener;
  Function removeAnnotationListener;

  DateTime _currentDate = DateTime.now().midnight;
  String log = "";
  Completer<GoogleMapController> _controller = Completer();
  Set<Circle> circles = {};
  Set<Circle> _allCircles = {};
  Set<GeofenceMarker> _geofences = {};
  Set<Marker> _currentPosition = {};

//  Set<Marker> _annotations = {};
//  bg.Location _stationaryLocation;
//  List<GeofenceMarker> _geofenceEvents = [];

  Set<Circle> _geofenceEventEdges = {};
  Set<Circle> _geofenceEventLocations = {};
  Set<Circle> _stationaryMarker = {};

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  MarkerId selectedMarker;

  CameraPosition _initialPosition;
  List<Annotation> annotations = [];
  List<Location> locations = [];

  String _darkMapStyle;
  String _normalMapStyle;

  @override
  void initState() {
    super.initState();
    final todayLocations = Provider.of<LocationNotifier>(context, listen: false)
        .locationsPerDate[DateTime.now().midnight];
    if (todayLocations?.isNotEmpty ?? false) {
      logger.i('[MapPage] initState() todayLocations.isNotEmpty');
      final ll = LatLng(todayLocations.last.coords.latitude,
          todayLocations.last.coords.longitude);
      _initialPosition = CameraPosition(
        target: ll,
        zoom: 16,
      );
    }
    rootBundle.loadString('assets/dark_map_style.json').then((string) {
      _darkMapStyle = string;
    });
    rootBundle.loadString('assets/normal_map_style.json').then((string) {
      _normalMapStyle = string;
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    removeLocationListener = Provider.of<LocationNotifier>(context).addListener(
      (state) {
        logger.i('[MapPage] LocationNotifier');
        if (state.newLocation != null && _currentDate.isToday) {
          _onLocation(state.newLocation);
        }
//        if (_currentDay.isToday) {
//          for (int i = 0; i < state.liveLocations.length; i++) {
//            _locations.add(CircleMarker(
//                point: LatLng(
//                    50.1 + Random().nextInt(9), 0.0 + Random().nextInt(9)),
//                color: Colors.black,
//                radius: 5.0));
//          }
//        }
      },
    );

    removeAnnotationListener = context.read<AnnotationNotifier>().addListener(
      (state) {
        logger.i('[MapPage] AnnotationNotifier');
        if (state != null && _currentDate.isToday) {
          _onAnnotation(state);
        }
      },
    );

    removeGeofenceEventListener =
        Provider.of<GeofenceEventNotifier>(context).addListener(
      (state) {
        logger.i('[MapPage] GeofenceEventNotifier');
        if (state.geofenceEvent != null && _currentDate.isToday) {
          _onGeofenceEvent(state.geofenceEvent);
        }
      },
    );

    removeGeofenceListener = Provider.of<GeofenceNotifier>(context).addListener(
      (state) {
        logger.i('[MapPage] GeofenceNotifier');
        _onGeofence(state.geofences);
      },
    );

//    removeGeofenceChangeListener =
//        Provider.of<GeofenceChangeNotifier>(context).addListener(
//      (state) {
//        logger('[MapPage] GeofenceChangeNotifier');
//        if (state.geofencesChangeEvent != null && _currentDate.isToday) {
//          _onGeofencesChange(state.geofencesChangeEvent);
//        }
//      },
//    );

    removeServiceListener = Provider.of<ServiceNotifier>(context).addListener(
      (state) {
        logger.i('[MapPage] ServiceNotifier');
        logger.i(state.isEnabled);
      },
    );

    removeDateListener = Provider.of<DateNotifier>(context).addListener(
      (state) {
        logger.i('[MapPage] DateNotifier');
        if (_currentDate != state.selectedDate) {
          _currentDate = state.selectedDate;
          _loadInitialDailyMarkers();
        }
      },
    );
  }

  void _onLocation(Location location) {
    logger.i('[MapPage] [onLocation]');
    LatLng ll = LatLng(location.coords.latitude, location.coords.longitude);
    _goToLocation(ll);
    _updateCurrentPositionMarker(ll);

    if (location.sample ?? false) {
      return;
    }
    addMarker(location);
  }

  void _onGeofenceTap(ColoredGeofence coloredGeofence) {
    logger.i('[MapPage] _onGeofenceTap');

    BottomSheets.showMapBottomSheet(
        context,
        InfoGeofenceHeader(coloredGeofence),
        InfoGeofenceBody(coloredGeofence),
        InfoGeofenceFooter(coloredGeofence));
  }

  void _onGeofence(List<ColoredGeofence> geofences) {
    _geofences.clear();
    try {
      geofences.forEach((ColoredGeofence coloredGeofence) {
        final geofenceMarker = GeofenceMarker(coloredGeofence, _onGeofenceTap);
        logger.i(
            '[MapPage] _onGeofence add identifier ${coloredGeofence.geofence.identifier}');
        logger.i('[MapPage] _onGeofence color ${geofenceMarker.fillColor}');
        _geofences.add(geofenceMarker);
      });
    } catch (ex) {
      logger.e('[MapPage] _onGeofence error $ex');
    }
    setState(() {
      updateAllCircles();
    });
  }

  void _onGeofenceEvent(bg.GeofenceEvent event) {
    logger.i('[MapPage] [_onGeofenceEvent]');
    GeofenceMarker marker = _geofences.firstWhere(
        (GeofenceMarker marker) =>
            marker.coloredGeofence.geofence.identifier == event.identifier,
        orElse: () => null);
    if (marker == null) {
      logger.w(
          "[_onGeofence] failed to find geofence marker: ${event.identifier}");
      return;
    }

    if (marker == null) {
      logger.w(
          '[onGeofence] WARNING - FAILED TO FIND GEOFENCE MARKER FOR GEOFENCE: ${event.identifier}');
      return;
    }

    bg.Location location = event.location;
    LatLng hit =
        new LatLng(location.coords.latitude, location.coords.longitude);

    // Update current position marker.
    _updateCurrentPositionMarker(hit);
    setState(() => updateAllCircles());
  }

  void _onAnnotation(AnnotationState annotationState) {
    if (annotationState.action == AnnotationAction.Added) {
      addAnnotationMarker(annotationState.annotation);
    } else if (annotationState.action == AnnotationAction.Removed) {
      markers.removeWhere((k, v) => k.value == annotationState.annotation.id);
      setState(() {});
    }
  }

//  void _onGeofencesChange(bg.GeofencesChangeEvent event) {
//    logger('[MapPage] [_onGeofencesChange]');
//    logger('[${bg.Event.GEOFENCESCHANGE}] - $event');
//    event.off.forEach((String identifier) {
//      _geofences.removeWhere((GeofenceMarker marker) {
//        return marker.geofence.identifier == identifier;
//      });
//    });
//
//    event.on.forEach((bg.Geofence geofence) {
//      _geofences.add(GeofenceMarker(geofence));
//    });
//
//    if (event.off.isEmpty && event.on.isEmpty) {
//      _geofences.clear();
//    }
//
//    setState(() {
//      updateAllCircles();
//    });
//  }

  void addMarker(Location location, {double hue}) {
    final MarkerId markerId = MarkerId(location.uuid);
    final Marker marker = Marker(
      markerId: markerId,
      icon: pinPositionMarkerIcon,
      onTap: () => _onLocationTap(location),
      position: LatLng(
        location.coords.latitude,
        location.coords.longitude,
      ),
      zIndex: 0.1,
    );
    markers[markerId] = marker;
    setState(() {
      markers[markerId] = marker;
    });
  }

  void addAnnotationMarker(Annotation annotation) {
    final MarkerId markerId = MarkerId(annotation.id);
    final Marker marker = Marker(
      markerId: markerId,
      icon: annotationPositionMarkerIcon,
      onTap: () => _onAnnotationTap(annotation),
      position: LatLng(
        annotation.latitude,
        annotation.longitude,
      ),
      zIndex: 0.2,
    );
    markers[markerId] = marker;
    setState(() {
      markers[markerId] = marker;
    });
  }

  /// Update Big Blue current position dot.
  void _updateCurrentPositionMarker(LatLng ll) {
    _currentPosition.clear();
    final MarkerId markerId = MarkerId("current_position");
    markers[markerId] = Marker(
      markerId: MarkerId("current_position"),
      position: ll,
      icon: currentPositionMarkerIcon,
      zIndex: 0.3,
    );
    setState(() {});
  }

  Future<void> _createMarkerImageFromAsset(BuildContext context) async {
    if (currentPositionMarkerIcon == null) {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context);
      BitmapDescriptor.fromAssetImage(
              imageConfiguration, 'assets/my_position_pin.png')
          .then(_updateCurrentBitmap);
    }
    if (annotationPositionMarkerIcon == null) {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context);
      BitmapDescriptor.fromAssetImage(
              imageConfiguration, 'assets/annotation_pin.png')
          .then(_updateAnnotationBitmap);
    }

    if (pinPositionMarkerIcon == null) {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context);
      BitmapDescriptor.fromAssetImage(
              imageConfiguration, 'assets/black_circle_pin.png')
          .then(_updateBlackBitmap);
    }

    if (selectedPinMarkerIcon == null) {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context);

      BitmapDescriptor.fromAssetImage(
              imageConfiguration, 'assets/selected_pin.png')
          .then(_updateSelectedBitmap);
    }

    if (genericPinMarkerIcon == null) {
      final ImageConfiguration imageConfiguration =
          createLocalImageConfiguration(context);
      BitmapDescriptor.fromAssetImage(
              imageConfiguration, 'assets/annotated_pin.png')
          .then(_updateGenericPinWithNoteBitmap);
    }
  }

  void _updateCurrentBitmap(BitmapDescriptor bitmap) {
    setState(() {
      currentPositionMarkerIcon = bitmap;
    });
  }

  void _updateBlackBitmap(BitmapDescriptor bitmap) {
    setState(() {
      pinPositionMarkerIcon = bitmap;
    });
  }

  void _updateSelectedBitmap(BitmapDescriptor bitmap) {
    setState(() {
      selectedPinMarkerIcon = bitmap;
    });
  }

  void _updateAnnotationBitmap(BitmapDescriptor bitmap) {
    setState(() {
      annotationPositionMarkerIcon = bitmap;
    });
  }

  void _updateGenericPinWithNoteBitmap(BitmapDescriptor bitmap) {
    setState(() {
      genericPinMarkerIcon = bitmap;
    });
  }

  Future<void> _goToLocation(LatLng loc) async {
    if (!mounted) return;
    final GoogleMapController controller = await _controller.future;
    try {
      controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            zoom: 16,
            target: LatLng(
              loc.latitude,
              loc.longitude,
            ),
          ),
        ),
      );
    } catch (ex) {
      logger.e('[MapPage] [Error] [_goToLocation]');
      logger.e(ex);
    }
  }

  void updateAllCircles() {
    logger.i('updateAllCircles');
    _allCircles.clear();
    _allCircles = _stationaryMarker
        .union(circles)
        .union(_geofences)
        .union(_geofenceEventEdges)
        .union(_geofenceEventLocations);
    logger.i('_allCircles.length');
    logger.i(_allCircles.length);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    logger.i('[MapPage] build');
    _createMarkerImageFromAsset(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition ?? _kGooglePlex,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              logger.i('[MapPage] onMapCreated');
              controller.setMapStyle(AppTheme.isNightModeOn(context)
                  ? _darkMapStyle
                  : _normalMapStyle);
              _controller.complete(controller);
              _loadInitialDailyMarkers();
            },
            markers: Set<Marker>.of(markers.values),
            circles: _allCircles,
          ),
          ManualDetectionPositionLayer(),
        ],
      ),
    );
  }

  _loadInitialDailyMarkers() {
    markers.clear();
    final dailyLocations = Provider.of<LocationNotifier>(context, listen: false)
        .getDayLocationsWithoutZeroLoc(_currentDate);
    if (dailyLocations?.isNotEmpty ?? false) {
      for (Location location in dailyLocations) {
        final MarkerId markerId = MarkerId(location.uuid);
        final icon = Hive.box<String>('pinNotes').containsKey(location.uuid)
            ? genericPinMarkerIcon
            : pinPositionMarkerIcon;
        final Marker marker = Marker(
          markerId: markerId,
          icon: icon,
          onTap: () => _onLocationTap(location),
          position: LatLng(
            location.coords.latitude,
            location.coords.longitude,
          ),
          zIndex: 0.1,
        );
        markers[markerId] = marker;
      }
      if (_currentDate.isToday) {
        _updateCurrentPositionMarker(
          LatLng(
            dailyLocations.last.coords.latitude,
            dailyLocations.last.coords.longitude,
          ),
        );
      }
    }
    final annotations = context
        .read<AnnotationNotifier>()
        .annotations
        .where((a) => a.dateTime.isSameDay(_currentDate));
    if (annotations.isNotEmpty) {
      for (Annotation annotation in annotations) {
        final MarkerId markerId = MarkerId(annotation.id);
        final Marker marker = Marker(
          markerId: markerId,
          icon: annotationPositionMarkerIcon,
          onTap: () => _onAnnotationTap(annotation),
          position: LatLng(
            annotation.latitude,
            annotation.longitude,
          ),
          zIndex: 0.2,
        );
        markers[markerId] = marker;
      }
    }
    setState(() {});
  }

  _onLocationTap(Location location) async {
    logger.i('[MapPage] _onLocationTap');
    String selectedPinId = '${location.uuid}_tmp';
    final MarkerId markerId = MarkerId(selectedPinId);
//    final MarkerId markerId = MarkerId('${location.uuid}');
    final Marker marker = Marker(
      markerId: markerId,
      icon: selectedPinMarkerIcon,
      position: LatLng(
        location.coords.latitude,
        location.coords.longitude,
      ),
      zIndex: 0.4,
    );

    setState(() {
      markers[markerId] = marker;
    });

    final dailyLocations = Provider.of<LocationNotifier>(context, listen: false)
        .getDayLocationsWithoutZeroLoc(_currentDate);
    final initialPage = dailyLocations
        .indexOf(dailyLocations.firstWhere((l) => l.uuid == location.uuid));
    final PageController pageController =
        PageController(initialPage: initialPage);
    final notifier = CurrentIndexNotifier(
        initialPage, dailyLocations, Hive.box<String>('pinNotes'));
    final infoPinNotifier = InfoPinNotifier();

    await BottomSheets.showMapBottomSheet(
        context,
        MultiProvider(
          providers: [
            StateNotifierProvider<InfoPinNotifier, InfoPinState>.value(
              value: infoPinNotifier,
            ),
            StateNotifierProvider<CurrentIndexNotifier, IndexState>.value(
              value: notifier,
            ),
          ],
          child: InfoPinHeader(
            pageController: pageController,
          ),
        ),
        MultiProvider(
          providers: [
            StateNotifierProvider<InfoPinNotifier, InfoPinState>.value(
              value: infoPinNotifier,
            ),
            StateNotifierProvider<CurrentIndexNotifier, IndexState>.value(
              value: notifier,
            ),
          ],
          child: InfoPinBody(
            pageController: pageController,
            locations: dailyLocations,
            initialPage: initialPage,
            onNoteAdded: (String uuid, String text) {
              setState(() {
                final MarkerId markerId = MarkerId(uuid);
                markers[markerId] =
                    markers[markerId].copyWith(iconParam: genericPinMarkerIcon);
                // zoom in to the selected camera position
              });
            },
            onNoteRemoved: (String uuid) {
              setState(() {
                final MarkerId markerId = MarkerId(uuid);
                markers[markerId] = markers[markerId]
                    .copyWith(iconParam: pinPositionMarkerIcon);
                // zoom in to the selected camera position
              });
            },
            selectPin: (location) {
              Marker marker;
              setState(() {
                markers.removeWhere((k, v) => k.value == selectedPinId);
                selectedPinId = '${location.uuid}_tmp';
                final MarkerId markerId = MarkerId(selectedPinId);
                marker = Marker(
                  markerId: markerId,
                  icon: selectedPinMarkerIcon,
                  position: LatLng(
                    location.coords.latitude,
                    location.coords.longitude,
                  ),
                  zIndex: 0.4,
                );
                markers[markerId] = marker;
                // zoom in to the selected camera position
              });
              _controller.future.then((controller) {
                controller.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                    bearing: 0,
                    target: marker.position,
                    zoom: 19,
                  ),
                ));
              });
            },
          ),
        ),
        MultiProvider(
          providers: [
            StateNotifierProvider<InfoPinNotifier, InfoPinState>.value(
              value: infoPinNotifier,
            ),
            StateNotifierProvider<CurrentIndexNotifier, IndexState>.value(
              value: notifier,
            ),
          ],
          child: InfoPinFooter(
            onNoteAdded: (String uuid, String text) {
              setState(() {
                final MarkerId markerId = MarkerId(uuid);
                markers[markerId] =
                    markers[markerId].copyWith(iconParam: genericPinMarkerIcon);
                // zoom in to the selected camera position
              });
            },
            onNoteRemoved: (String uuid) {
              setState(() {
                final MarkerId markerId = MarkerId(uuid);
                markers[markerId] = markers[markerId]
                    .copyWith(iconParam: pinPositionMarkerIcon);
                // zoom in to the selected camera position
              });
            },
          ),
        ));

    notifier.dispose();
    pageController.dispose();
    markers.removeWhere((k, v) => k.value == selectedPinId);
    setState(() {});
  }

  _onAnnotationTap(Annotation annotation) async {
    final notifier = InfoAnnotationNotifier(annotation);
    logger.i('[MapPage] _onAnnotationTap');

    await BottomSheets.showMapBottomSheet(
        context,
        StateNotifierProvider.value(
          value: notifier,
          child: InfoAnnotationHeader(),
        ),
        StateNotifierProvider.value(
          value: notifier,
          child: InfoAnnotationBody(),
        ),
        StateNotifierProvider.value(
          value: notifier,
          child: InfoAnnotationFooter(),
        ));

    notifier.dispose();
  }

  @override
  void dispose() {
    logger.i('[MapPage] dispose()');
    removeServiceListener();
    removeDateListener();
    removeLocationListener();
    removeGeofenceListener();
    removeGeofenceEventListener();
    removeAnnotationListener();
    super.dispose();
  }
}
