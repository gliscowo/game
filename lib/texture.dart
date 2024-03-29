import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';

import 'mipmaps.dart';

final _textures = <String, int>{};

int loadTexture(String name, {bool mipmap = false, double maxAnisotropy = 1}) {
  if (_textures.containsKey(name)) return _textures[name]!;

  final imageData = decodePng(File("resources/texture/$name.png").readAsBytesSync())
      ?.convert(format: Format.uint8, numChannels: 4, alpha: 255);
  if (imageData == null) {
    throw "Failed to load texture $name";
  }

  final idPtr = malloc<UnsignedInt>();
  gl.createTextures(glTexture2d, 1, idPtr);

  final texture = idPtr.value;
  malloc.free(idPtr);

  gl.textureParameteri(texture, glTextureMinFilter, glNearestMipmapLinear);
  gl.textureParameteri(texture, glTextureMagFilter, glNearest);
  gl.textureParameterf(texture, glTextureMaxAnisotropy, maxAnisotropy);

  final maldHarder = log2(imageData.width.toDouble());
  var textureLevels = <Image>[imageData];
  if (mipmap && maldHarder.toInt() == maldHarder) {
    final maxLevel = min(log2(imageData.width.toDouble()).toInt(), 4);
    textureLevels = generateMipLevels(imageData, maxLevel);
  }

  gl.textureStorage2D(texture, textureLevels.length, glRgba8, imageData.width, imageData.height);
  for (var level = 0; level < textureLevels.length; level++) {
    _uploadTextureLevel(texture, level, textureLevels[level]);
  }

  return _textures[name] = texture;
}

void _uploadTextureLevel(int texture, int level, Image imageData) {
  final bufferSize = imageData.width * imageData.height * 4;
  final pixels = malloc<Uint8>(bufferSize);
  pixels.asTypedList(bufferSize).setRange(0, bufferSize, imageData.buffer.asUint8List());

  gl.textureSubImage2D(texture, level, 0, 0, imageData.width, imageData.height, glRgba, glUnsignedByte, pixels.cast());

  malloc.free(pixels);
}

double log2(double x) => log(x) / log(2);
