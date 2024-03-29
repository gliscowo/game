import 'dart:math';

import 'package:image/image.dart';

//TODO 🤢

extension ARGB on Image {
  int getPixelArgb(int x, int y) {
    final pixel = getPixel(x, y);
    return (pixel.aNormalized * 255).toInt() << 24 |
        (pixel.rNormalized * 255).toInt() << 16 |
        (pixel.gNormalized * 255).toInt() << 8 |
        (pixel.bNormalized * 255).toInt();
  }
}

const double _alphaCutoutCutoff = 96 / 255;
final List<double> _pow22 = List.generate(256, (index) => pow(index / 255, 2.2).toDouble());

List<Image> generateMipLevels(Image image, int maxLevel) {
  var result = <Image>[image];
  var hasTransparency = _hasTransparentPixel(result[0]);

  for (int level = 1; level <= maxLevel; ++level) {
    var seed = result.last;
    var levelImage = Image.fromResized(seed, width: seed.width ~/ 2, height: seed.height ~/ 2, noAnimation: true);

    for (int x = 0; x < levelImage.width; ++x) {
      for (int y = 0; y < levelImage.height; ++y) {
        final (a, r, g, b) = _alphaBlend(
          seed.getPixelArgb(x * 2 + 0, y * 2 + 0),
          seed.getPixelArgb(x * 2 + 1, y * 2 + 0),
          seed.getPixelArgb(x * 2 + 0, y * 2 + 1),
          seed.getPixelArgb(x * 2 + 1, y * 2 + 1),
          hasTransparency,
        );

        levelImage.getPixel(x, y).aNormalized = a;
        levelImage.getPixel(x, y).rNormalized = r;
        levelImage.getPixel(x, y).gNormalized = g;
        levelImage.getPixel(x, y).bNormalized = b;
      }
    }

    result.add(levelImage);
  }

  return result;
}

bool _hasTransparentPixel(Image image) {
  for (int x = 0; x < image.width; ++x) {
    for (int y = 0; y < image.height; ++y) {
      if (image.getPixel(x, y).a == 0) {
        return true;
      }
    }
  }

  return false;
}

(double, double, double, double) _alphaBlend(int one, int two, int three, int four, bool hasTransparency) {
  if (hasTransparency) {
    var a = 0.0;
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    if (one >> 24 != 0) {
      a += _getPow22(one >> 24);
      r += _getPow22(one >> 16);
      g += _getPow22(one >> 8);
      b += _getPow22(one >> 0);
    }
    if (two >> 24 != 0) {
      a += _getPow22(two >> 24);
      r += _getPow22(two >> 16);
      g += _getPow22(two >> 8);
      b += _getPow22(two >> 0);
    }
    if (three >> 24 != 0) {
      a += _getPow22(three >> 24);
      r += _getPow22(three >> 16);
      g += _getPow22(three >> 8);
      b += _getPow22(three >> 0);
    }
    if (four >> 24 != 0) {
      a += _getPow22(four >> 24);
      r += _getPow22(four >> 16);
      g += _getPow22(four >> 8);
      b += _getPow22(four >> 0);
    }
    a /= 4.0;
    r /= 4.0;
    g /= 4.0;
    b /= 4.0;

    var aComponent = pow(a, 1 / 2.2).toDouble();
    var rComponent = pow(r, 1 / 2.2).toDouble();
    var gComponent = pow(g, 1 / 2.2).toDouble();
    var bComponent = pow(b, 1 / 2.2).toDouble();
    if (aComponent < _alphaCutoutCutoff) {
      aComponent = 0;
    }

    return (aComponent, rComponent, gComponent, bComponent);
  } else {
    var aComponent = _gammaBlend(one, two, three, four, 24);
    var rComponent = _gammaBlend(one, two, three, four, 16);
    var gComponent = _gammaBlend(one, two, three, four, 8);
    var bComponent = _gammaBlend(one, two, three, four, 0);
    return (aComponent, rComponent, gComponent, bComponent);
  }
}

double _gammaBlend(int one, int two, int three, int four, int componentOffset) {
  var c1 = _getPow22(one >> componentOffset);
  var c2 = _getPow22(two >> componentOffset);
  var c3 = _getPow22(three >> componentOffset);
  var c4 = _getPow22(four >> componentOffset);

  return pow((c1 + c2 + c3 + c4) * 0.25, 1 / 2.2).toDouble();
}

double _getPow22(int color) {
  return _pow22[color & 0xFF];
}
