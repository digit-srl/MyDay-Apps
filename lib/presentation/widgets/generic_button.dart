import 'package:auto_size_text/auto_size_text.dart';
import 'package:diary/utils/colors.dart';
import 'package:flutter/material.dart';
import '../../utils/styles.dart';

/*
 * Wrapper widget for buttons used principally inside home page sheets, but
 * usable everywhere. In general, an 'important' button is a colored raised
 * button, meanwhile a less important button can use the flat style
 */
class GenericButton extends StatelessWidget {
  final String text;
  final Function onPressed;
  final bool withBorder;
  final Color color;

  const GenericButton({
    Key key,
    @required this.text,
    @required this.onPressed,
    this.withBorder = true,
    this.color
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return withBorder
        ? RaisedButton(
            highlightColor: Colors.white.withOpacity(0.3),
            splashColor: Colors.white.withOpacity(0.3),
            color: color ?? Theme.of(context).accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            onPressed: onPressed,
            shape: RoundedRectangleBorder(
              borderRadius: new BorderRadius.circular(10.0),
            ),
            child: AutoSizeText(
              text,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.button,
            ),
          )

        : FlatButton(
            highlightColor:
                Theme.of(context).textTheme.body1.color.withOpacity(0.3),
            splashColor:
                Theme.of(context).textTheme.body1.color.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            onPressed: onPressed,
            shape: RoundedRectangleBorder(
              borderRadius: new BorderRadius.circular(10.0),
            ),
            child: AutoSizeText(
              text,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.button
                  .copyWith(color: Theme.of(context).textTheme.body1.color),
            ),
          );
  }
}
