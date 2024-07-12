import 'package:dartemis/dartemis.dart';
import 'package:diamond_gl/diamond_gl.dart';

import 'chunk_storage.dart';

extension TriCount on MeshBuffer {
  static int triCount = 0;
  void drawAndCount() {
    draw();
    triCount += vertexCount ~/ 3;
  }
}

extension WorldProperties on World {
  static const chunkManager = 'chunk_manager';

  ChunkStorage get chunks => properties[chunkManager] as ChunkStorage;
  set chunks(ChunkStorage storage) => properties[chunkManager] = storage;
}
