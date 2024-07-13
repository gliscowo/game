import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:fast_noise/fast_noise.dart' hide DoubleExtension;
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import 'math.dart';
import 'worker.dart';

class DiscretePosition {
  final int x, y, z;

  const DiscretePosition(this.x, this.y, this.z);
  const DiscretePosition.origin() : this(0, 0, 0);

  DiscretePosition offset({int x = 0, int y = 0, int z = 0}) => DiscretePosition(this.x + x, this.y + y, this.z + z);
  DiscretePosition move(AxisDirection direction, [int by = 1]) => offset(
        x: direction.offset.x * by,
        y: direction.offset.y * by,
        z: direction.offset.z * by,
      );

  DiscretePosition operator +(DiscretePosition other) => DiscretePosition(x + other.x, y + other.y, z + other.z);
  DiscretePosition operator -(DiscretePosition other) => DiscretePosition(x - other.x, y - other.y, z - other.z);
  DiscretePosition operator *(int scale) => DiscretePosition(x * scale, y * scale, z * scale);

  Vector3 toVec3() => Vector3(x.toDouble(), y.toDouble(), z.toDouble());

  @override
  int get hashCode => (y + z * 31) * 31 + x;
  @override
  bool operator ==(Object other) => other is DiscretePosition && x == other.x && y == other.y && z == other.z;

  @override
  String toString() => '[$x, $y, $z]';
}

enum AxisDirection {
  positiveX(DiscretePosition(1, 0, 0)),
  negativeX(DiscretePosition(-1, 0, 0)),
  positiveY(DiscretePosition(0, 1, 0)),
  negativeY(DiscretePosition(0, -1, 0)),
  positiveZ(DiscretePosition(0, 0, 1)),
  negativeZ(DiscretePosition(0, 0, -1));

  final DiscretePosition offset;
  const AxisDirection(this.offset);
}

final _noise = ValueNoise(seed: 1337);

class Chunk {
  static const size = 16;
  final Uint8List blockStorage = Uint8List(size * size * size);

  bool hasBlockAt(DiscretePosition pos) => blockStorage[_storageIndex(pos.x, pos.y, pos.z)] != 0;

  int _storageIndex(int x, int y, int z) => x << 8 | y << 4 | z;

  int operator [](DiscretePosition pos) => blockStorage[_storageIndex(pos.x, pos.y, pos.z)];
  operator []=(DiscretePosition pos, int data) => blockStorage[_storageIndex(pos.x, pos.y, pos.z)] = data;

  static DiscretePosition worldPosToLocalPos(DiscretePosition pos) =>
      DiscretePosition(pos.x % 16, pos.y % 16, pos.z % 16);
}

enum ChunkStatus { empty, scheduled, loaded }

mixin ChunkView {
  Chunk chunkAt(DiscretePosition pos);
  ChunkStatus statusAt(DiscretePosition pos);

  bool hasBlockAt(DiscretePosition pos) => chunkAt(worldPosToChunkPos(pos)).hasBlockAt(Chunk.worldPosToLocalPos(pos));

  (DiscretePosition, int)? raycast(Vector3 from, Vector3 to) {
    // from = Vector3.copy(from);
    // to = Vector3.copy(to);

    // to.x = to.x.lerp(-1e-5, from.x);
    // to.y = to.y.lerp(-1e-5, from.y);
    // to.z = to.z.lerp(-1e-5, from.z);
    // from.x = from.x.lerp(-1e-5, to.x);
    // from.y = from.y.lerp(-1e-5, to.y);
    // from.z = from.z.lerp(-1e-5, to.z);
    final ray = to - from;

    final stepX = ray.x.sign.toInt(), stepY = ray.y.sign.toInt(), stepZ = ray.z.sign.toInt();
    final tDeltaX = stepX == 0 ? double.maxFinite : stepX / ray.x,
        tDeltaY = stepY == 0 ? double.maxFinite : stepY / ray.y,
        tDeltaZ = stepZ == 0 ? double.maxFinite : stepZ / ray.z;

    var tMaxX = tDeltaX * (stepX > 0 ? 1 - from.x % 1 : from.x % 1),
        tMaxY = tDeltaY * (stepY > 0 ? 1 - from.y % 1 : from.y % 1),
        tMaxZ = tDeltaZ * (stepZ > 0 ? 1 - from.z % 1 : from.z % 1);

    var x = from.x.floor(), y = from.y.floor(), z = from.z.floor();
    while (tMaxX <= 1.0 || tMaxY <= 1.0 || tMaxZ <= 1.0) {
      if (tMaxX < tMaxY) {
        if (tMaxX < tMaxZ) {
          x += stepX;
          tMaxX += tDeltaX;
        } else {
          z += stepZ;
          tMaxZ += tDeltaZ;
        }
      } else if (tMaxY < tMaxZ) {
        y += stepY;
        tMaxY += tDeltaY;
      } else {
        z += stepZ;
        tMaxZ += tDeltaZ;
      }

      final pos = DiscretePosition(x, y, z);
      if (hasBlockAt(pos)) {
        return (pos, chunkAt(worldPosToChunkPos(pos))[Chunk.worldPosToLocalPos(pos)]);
      }
    }

    return null;
  }

  static DiscretePosition worldPosToChunkPos(DiscretePosition pos) =>
      DiscretePosition(pos.x >> 4, pos.y >> 4, pos.z >> 4);
}

class ChunkStorage with ChunkView {
  static final _logger = Logger('game.chunk_storage');

  final Map<DiscretePosition, Chunk> _chunks = HashMap();
  final Set<DiscretePosition> _scheduledChunks = HashSet();

  Future<void> pregen(ChunkGenWorkers workers, int radius, int verticalRange) async =>
      await Future.wait(iterateOutwards(radius, verticalRange).map((e) => _enqueue(workers, e)));

  void scheduleChunk(ChunkGenWorkers workers, DiscretePosition pos) {
    if (statusAt(pos) != ChunkStatus.empty) {
      _logger.warning('Tried to schedule ${statusAt(pos).name} chunk for generation again');
      return;
    }

    _enqueue(workers, pos);
  }

  Future<void> _enqueue(ChunkGenWorkers workers, DiscretePosition chunkPos) {
    _scheduledChunks.add(chunkPos);
    return workers.process(chunkPos).then((chunk) {
      _chunks[chunkPos] = chunk;
      _scheduledChunks.remove(chunkPos);
    });
  }

  ChunkView maskChunkForCompilation(DiscretePosition chunkPos) => MaskedChunkView.ofChunk(this, chunkPos);

  @override
  Chunk chunkAt(DiscretePosition pos) => _chunks[pos] ?? const EmptyChunk();

  @override
  ChunkStatus statusAt(DiscretePosition pos) => _chunks.containsKey(pos)
      ? ChunkStatus.loaded
      : _scheduledChunks.contains(pos)
          ? ChunkStatus.scheduled
          : ChunkStatus.empty;
}

class EmptyChunk implements Chunk {
  const EmptyChunk();

  @override
  int operator [](DiscretePosition pos) => 0;
  @override
  void operator []=(DiscretePosition pos, int data) => 0;
  @override
  int _storageIndex(int x, int y, int z) => 0;
  @override
  Uint8List get blockStorage => Uint8List(0);
  @override
  bool hasBlockAt(DiscretePosition pos) => false;
}

// TODO optimize
class MaskedChunkView extends ChunkStorage {
  MaskedChunkView._();
  factory MaskedChunkView.ofChunk(ChunkStorage storage, DiscretePosition chunkPos) {
    final masked = MaskedChunkView._();

    masked._chunks[DiscretePosition.origin()] = storage.chunkAt(chunkPos);

    final xPosSlice = masked._chunks[DiscretePosition(1, 0, 0)] = SliceChunk(AxisDirection.positiveX);
    final xNegSlice = masked._chunks[DiscretePosition(-1, 0, 0)] = SliceChunk(AxisDirection.negativeX);
    for (var y = 0; y < Chunk.size; y++) {
      for (var z = 0; z < Chunk.size; z++) {
        xPosSlice[DiscretePosition(0, y, z)] = storage.chunkAt(chunkPos.offset(x: 1))[DiscretePosition(0, y, z)];
        xNegSlice[DiscretePosition(15, y, z)] = storage.chunkAt(chunkPos.offset(x: -1))[DiscretePosition(15, y, z)];
      }
    }

    final yPosSlice = masked._chunks[DiscretePosition(0, 1, 0)] = SliceChunk(AxisDirection.positiveY);
    final yNegSlice = masked._chunks[DiscretePosition(0, -1, 0)] = SliceChunk(AxisDirection.negativeY);
    for (var x = 0; x < Chunk.size; x++) {
      for (var z = 0; z < Chunk.size; z++) {
        yPosSlice[DiscretePosition(x, 0, z)] = storage.chunkAt(chunkPos.offset(y: 1))[DiscretePosition(x, 0, z)];
        yNegSlice[DiscretePosition(x, 15, z)] = storage.chunkAt(chunkPos.offset(y: -1))[DiscretePosition(x, 15, z)];
      }
    }

    final zPosSlice = masked._chunks[DiscretePosition(0, 0, 1)] = SliceChunk(AxisDirection.positiveZ);
    final zNegSlice = masked._chunks[DiscretePosition(0, 0, -1)] = SliceChunk(AxisDirection.negativeZ);
    for (var x = 0; x < Chunk.size; x++) {
      for (var y = 0; y < Chunk.size; y++) {
        zPosSlice[DiscretePosition(x, y, 0)] = storage.chunkAt(chunkPos.offset(z: 1))[DiscretePosition(x, y, 0)];
        zNegSlice[DiscretePosition(x, y, 15)] = storage.chunkAt(chunkPos.offset(z: -1))[DiscretePosition(x, y, 15)];
      }
    }

    return masked;
  }
}

class SliceChunk implements Chunk {
  @override
  final Uint8List blockStorage = Uint8List(256);

  final AxisDirection _side;
  SliceChunk(this._side);

  @override
  int _storageIndex(int x, int y, int z) => switch (_side) {
        AxisDirection.positiveX || AxisDirection.negativeX => y << 4 | z,
        AxisDirection.positiveY || AxisDirection.negativeY => x << 4 | z,
        AxisDirection.positiveZ || AxisDirection.negativeZ => x << 4 | y
      };

  @override
  int operator [](DiscretePosition pos) => blockStorage[_storageIndex(pos.x, pos.y, pos.z)];
  @override
  operator []=(DiscretePosition pos, int data) => blockStorage[_storageIndex(pos.x, pos.y, pos.z)] = data;

  @override
  bool hasBlockAt(DiscretePosition pos) => blockStorage[_storageIndex(pos.x, pos.y, pos.z)] != 0;
}

typedef ChunkGenWorkers = WorkerPool<DiscretePosition, Chunk>;
Future<ChunkGenWorkers> createChunkGenWorkers(int size) {
  return WorkerPool.create(() {}, _generateChunk, size, (idx) => 'chunk-gen-worker-$idx');
}

Chunk _generateChunk(DiscretePosition basePos) {
  final chunk = Chunk();
  basePos *= 16;

  for (var blockX = 0; blockX < Chunk.size; blockX++) {
    for (var blockY = 0; blockY < Chunk.size; blockY++) {
      for (var blockZ = 0; blockZ < Chunk.size; blockZ++) {
        if (basePos.y + blockY <
            _noise.getNoise2((basePos.x + blockX).toDouble(), (basePos.z + blockZ).toDouble()) * 15) {
          chunk[DiscretePosition(blockX, blockY, blockZ)] = 1;
        }
      }
    }
  }

  return chunk;
}
