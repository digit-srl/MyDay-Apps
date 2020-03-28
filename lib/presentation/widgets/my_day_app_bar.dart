import 'package:diary/application/day_notifier.dart';
import 'package:diary/utils/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:diary/application/location_notifier.dart';
import 'package:diary/application/date_notifier.dart';
import 'package:diary/utils/extensions.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

class MyDayAppBar extends StatefulWidget {
  final Function changePage;

  const MyDayAppBar({Key key, this.changePage}) : super(key: key);

  @override
  _MyDayAppBarState createState() => _MyDayAppBarState();
}

class _MyDayAppBarState extends State<MyDayAppBar> {
  int _currentPage = 0;

//  final rangeDate = [
//    DateTime(2020, 3, 7),
//    DateTime(2020, 3, 8),
//    DateTime(2020, 3, 10),
//    DateTime(2020, 3, 12),
//    DateTime(2020, 3, 13),
//    DateTime.now().withoutMinAndSec()
//  ];

  _MyDayAppBarState() {
//    rangeDate.forEach(print);
  }

  bool isMoving = false;

  @override
  Widget build(BuildContext context) {
    print('[AppBar] build()');
    final dates = Provider.of<LocationNotifier>(context, listen: false).dates;

    return WillPopScope(
      onWillPop: () {
        if (_currentPage != 0) {
          widget.changePage(0);
          setState(() {
            _currentPage = 0;
          });
          return Future.value(false);
        }
        return Future.value(true);
      },
      child: Container(
        color: Colors.white.withOpacity(0.85),

        // todo esperimento: appbar con sfondo gradiente
        //decoration: BoxDecoration(
        //  gradient: LinearGradient(
        //    begin: Alignment.topCenter,
        //    end: Alignment.bottomCenter,
        //    colors: [Colors.white,  Colors.white.withOpacity(0)]
        //  )
        //),
        height: 60,
        padding: const EdgeInsets.only(top: 5.0, left: 5.0, right: 5.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            IconButton(
                icon: Icon(_currentPage == 0 ? Icons.map : Icons.arrow_back),
                onPressed: () {
                  widget.changePage(_currentPage == 0 ? 1 : 0);
                  setState(() {
                    _currentPage = _currentPage == 0 ? 1 : 0;
                  });
                }),
            FlatButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: Provider.of<DateState>(context, listen: false)
                      .selectedDate
                      .withoutMinAndSec(),
                  firstDate: dates.first,
                  lastDate: dates.last.add(Duration(minutes: 1)),
                  selectableDayPredicate: (DateTime date) => dates.contains(
                    date.withoutMinAndSec(),
                  ),
                  // datepicker manual customization (it is aflutter bug:
                  // https://github.com/flutter/flutter/issues/19623#issuecomment-568009162)
                  builder: (context, child) => Theme(
                    data: ThemeData(
                      colorScheme: ColorScheme(
                        background: Colors.white,
                        brightness: Brightness.light,
                        error: accentColor,
                        onBackground: Colors.black87,
                        onError: Colors.white,
                        onSurface: Colors.black87,
                        onSecondary: Colors.black87,
                        onPrimary: Colors.black,
                        primary: accentColor, //  FLAT BUTTON COLOR
                        primaryVariant: accentColor,
                        secondary: Colors.black,
                        secondaryVariant: Colors.black,
                        surface: Colors.white,
                      ),
                      primaryColor: accentColor, //  HEADER COLOR
                      accentColor: accentColor, // DATE COLOR
                      buttonTheme: ButtonThemeData(
                        textTheme: ButtonTextTheme.accent,
                      ),
                    ),
                    child: child,
                  ),
                );

                if (selected == null) return;
                Provider.of<DateNotifier>(context, listen: false)
                    .changeSelectedDate(selected);
              },
              shape: RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(16.0),
              ),
              icon: Icon(
                Icons.today,
                color: accentColor,
              ),
              label: Text(
                  context.select((DateState value) =>
                      value.isToday ? 'Oggi' : value.dateFormatted),
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
//          IconButton(
//              icon: Icon(Icons.change_history),
//              onPressed: () {
//                Provider.of<ServiceNotifier>(context, listen: false)
//                    .invertEnabled();
//                Provider.of<LocationNotifier>(context, listen: false)
//                    .addLocation(null);
//              }),
//            IconButton(
//                color: isMoving ? Colors.green : Colors.red,
//                icon: Icon(Icons.directions_walk),
//                onPressed: () {
//                  bg.BackgroundGeolocation.changePace(!isMoving);
//                  isMoving = !isMoving;
//                  setState(() {
//
//                  });
//                }),
            IconButton(
              icon: Icon(_currentPage == 0
                  ? Icons.collections_bookmark
                  : _currentPage == 1 ? Icons.gps_fixed : Icons.search),
              onPressed: () {
                if (_currentPage == 1) {
                  getCurrentLoc();
                } else {
                  widget.changePage(2);
                  setState(() {
                    _currentPage = 2;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  getCurrentLoc() {
    bg.BackgroundGeolocation.getCurrentPosition(
        persist: true,
        // <-- do not persist this location
        desiredAccuracy: 5,
        // <-- desire an accuracy of 40 meters or less
        maximumAge: 10000,
        // <-- Up to 10s old is fine.
        timeout: 10,
        // <-- wait 30s before giving up.
        samples: 10,
        // <-- sample just 1 location
        extras: {"getCurrentPosition": true}).then((bg.Location location) {
      print('[getCurrentPosition] - $location');
    }).catchError((error) {
      print('[getCurrentPosition] ERROR: $error');
    });
  }
}
