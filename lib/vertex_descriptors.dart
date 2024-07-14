import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

typedef TerrainVertexFunction = void Function(Vector3 pos, Vector3 normal, double u, double v);
final VertexDescriptor<TerrainVertexFunction> terrainVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 3);
    attribute('aNormal', VertexElement.float, 3);
    attribute('aUv', VertexElement.float, 2);
  },
  (buffer) => (pos, normal, u, v) {
    buffer.float3(pos.x, pos.y, pos.z);
    buffer.float3(normal.x, normal.y, normal.z);
    buffer.float2(u, v);
  },
);

typedef DebugEntityVertexFunction = void Function(Vector3 pos);
final VertexDescriptor<DebugEntityVertexFunction> debugEntityVertexDescriptor = VertexDescriptor(
  (attribute) => attribute('aPos', VertexElement.float, 3),
  (buffer) => (pos) => buffer.float3(pos.x, pos.y, pos.z),
);

typedef DebugLinesVertexFunction = void Function(Vector3 pos, Color color);
final VertexDescriptor<DebugLinesVertexFunction> debugLinesVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 3);
    attribute('aColor', VertexElement.float, 4);
  },
  (buffer) => (pos, color) {
    buffer.float3(pos.x, pos.y, pos.z);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
);

typedef PosColorVertexFunction = void Function(Vector3 pos, Color color);
final VertexDescriptor<PosColorVertexFunction> posColorVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 3);
    attribute('aColor', VertexElement.float, 4);
  },
  (buffer) => (pos, color) {
    buffer.float3(pos.x, pos.y, pos.z);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
);

typedef PosUvColorVertexFunction = void Function(Vector3 pos, double u, double v, Color color);
final VertexDescriptor<PosUvColorVertexFunction> posUvColorVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 3);
    attribute('aUv', VertexElement.float, 2);
    attribute('aColor', VertexElement.float, 4);
  },
  (buffer) => (pos, u, v, color) {
    buffer.float3(pos.x, pos.y, pos.z);
    buffer.float2(u, v);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
);

typedef TextVertexFunction = void Function(double x, double y, double u, double v, Color color);
final VertexDescriptor<TextVertexFunction> textVertexDescriptor = VertexDescriptor(
  (attribute) {
    attribute('aPos', VertexElement.float, 2);
    attribute('aUv', VertexElement.float, 2);
    attribute('aColor', VertexElement.float, 4);
  },
  (buffer) => (x, y, u, v, color) {
    buffer.float2(x, y);
    buffer.float2(u, v);
    buffer.float4(color.r, color.g, color.b, color.a);
  },
);
