import 'dart:ui';

class CurvesData {
  List<Offset> master;
  List<Offset> red;
  List<Offset> green;
  List<Offset> blue;
  String activeChannel; // 'master' | 'red' | 'green' | 'blue'

  CurvesData({
    this.master = const [Offset(0, 0), Offset(1, 1)],
    this.red = const [Offset(0, 0), Offset(1, 1)],
    this.green = const [Offset(0, 0), Offset(1, 1)],
    this.blue = const [Offset(0, 0), Offset(1, 1)],
    this.activeChannel = 'master',
  });

  List<Offset> get activePoints {
    switch (activeChannel) {
      case 'red':
        return red;
      case 'green':
        return green;
      case 'blue':
        return blue;
      default:
        return master;
    }
  }

  set activePoints(List<Offset> points) {
    switch (activeChannel) {
      case 'red':
        red = points;
        break;
      case 'green':
        green = points;
        break;
      case 'blue':
        blue = points;
        break;
      default:
        master = points;
    }
  }

  CurvesData copy() => CurvesData(
    master: List<Offset>.from(master),
    red: List<Offset>.from(red),
    green: List<Offset>.from(green),
    blue: List<Offset>.from(blue),
    activeChannel: activeChannel,
  );
}
