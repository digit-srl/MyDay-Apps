import 'package:diary/utils/alerts.dart';
import 'package:diary/utils/generic_utils.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LogsPage extends StatelessWidget {
  bool isEmpty = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logs Debugger',
          style: Theme.of(context).textTheme.title,
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<String>('logs').listenable(),
        builder: (BuildContext context, Box<String> value, Widget child) {
          final logs = value.values.toList().reversed.toList();
          if (logs.isEmpty) {
            isEmpty = true;
            return Center(
              child: Text('Nessun log presente'),
            );
          }
          isEmpty = false;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.separated(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    logs[index].substring(0, logs[index].indexOf(' ')),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  leading: Icon(Icons.developer_mode),
                  subtitle:
                      Text(logs[index].substring(logs[index].indexOf(' ') + 1)),
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return Divider();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.clear),
        backgroundColor: Theme.of(context).accentColor,
        onPressed: () {
//          Hive.box<Place>('places').clear();
          if (!isEmpty) {
            Alerts.showAlertWithPosNegActions(
                context,
                "Elimina log",
                "Sei sicuro di voler eliminare tutti i log?",
                "Sì, elimina",
                () {
                    Hive.box<String>('logs').clear();
                }
            );
          }
        },
      ),
    );
  }
}
