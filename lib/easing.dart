import 'dart:math';

extension Easings on double {
  double easeSine() => sin(this * pi - pi / 2) * .5 + .5;
  double easeQuadratic() => this < 0.5 ? 2 * this * this : (1 - pow(-2 * this + 2, 2) / 2);
  double easeCubic() => this < 0.5 ? 4 * this * this * this : (1 - pow(-2 * this + 2, 3) / 2);
  double easeQuartic() => this < 0.5 ? 8 * this * this * this * this : (1 - pow(-2 * this + 2, 4) / 2);

  double easeExpo() {
    if (this == 0) return 0;
    if (this == 1) return 1;

    return this < 0.5 ? pow(2, 20 * this - 10) / 2 : (2 - pow(2, -20 * this + 10)) / 2;
  }
}
