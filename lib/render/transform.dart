import 'package:dartemis/dartemis.dart';
import 'package:vector_math/vector_math.dart';

class Position extends Component {
  final Vector3 value;
  Position({double x = 0, double y = 0, double z = 0}) : value = Vector3(x, y, z);
  Position.fromVector(Vector3 pos) : value = Vector3.copy(pos);

  double get x => value.x;
  set x(double x) => value.x = x;

  double get y => value.y;
  set y(double y) => value.y = y;

  double get z => value.z;
  set z(double z) => value.z = z;
}

class Velocity extends Component {
  final Vector3 value;
  Velocity({double x = 0, double y = 0, double z = 0}) : value = Vector3(x, y, z);

  double get x => value.x;
  set x(double x) => value.x = x;

  double get y => value.y;
  set y(double y) => value.y = y;

  double get z => value.z;
  set z(double z) => value.z = z;
}

class Orientation extends Component {
  double yaw, pitch, roll;
  Orientation({this.yaw = 0, this.pitch = 0, this.roll = 0});
}
