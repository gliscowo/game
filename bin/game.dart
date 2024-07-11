import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:dartemis/dartemis.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:game/chunk_storage.dart';
import 'package:game/components/camera.dart';
import 'package:game/components/chunk.dart';
import 'package:game/components/debug.dart';
import 'package:game/components/fysik.dart';
import 'package:game/components/transform.dart';
import 'package:game/context.dart';
import 'package:game/game.dart';
import 'package:game/input.dart';
import 'package:game/obj.dart';
import 'package:game/text/text.dart';
import 'package:game/text/text_renderer.dart';
import 'package:game/texture.dart';
import 'package:game/vertex_descriptors.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

typedef GLFWerrorfun = Void Function(Int, Pointer<Char>);

final Logger _logger = Logger("game");
final Logger _glfwLogger = Logger("game.glfw");

const tickRate = 64;
const renderGroup = 1;
const logicGroup = 2;

Future<void> main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((event) {
    print("[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}");
  });

  loadOpenGL();
  loadGLFW("resources/lib/libglfw.so.3");
  initDiamondGL(logger: _logger);

  final parser = setupArgs();
  final args = parser.parse(arguments);
  if (args.wasParsed('help')) {
    print(parser.usage);
    return;
  }

  if (glfw.init() != glfwTrue) {
    _logger.severe("GLFW init failed");
    exit(-1);
  }

  glfw.setErrorCallback(Pointer.fromFunction<GLFWerrorfun>(onGlfwError));

  final window = Window(1000, 550, "game", debug: true);
  glfw.makeContextCurrent(window.handle);

  attachGlErrorCallback();
  minGlDebugSeverity = glDebugSeverityLow;
  gl.debugMessageInsert(
      glDebugSourceThirdParty, glDebugTypeMarker, 0, glDebugSeverityHigh, -1, "bruh".toNativeUtf8().cast());

  final renderContext = RenderContext(
    window,
    await Future.wait([
      vertFragProgram("gui_pos_color", "gui_pos_color", "gui_pos_color"),
      vertFragProgram("gui_pos_uv_color", "gui_pos_uv_color", "gui_pos_uv_color"),
      vertFragProgram("text", "text", "text"),
      vertFragProgram("terrain", "terrain", "terrain"),
    ]),
  );

  final cascadia = FontFamily("CascadiaCode", 30);
  final notoSans = FontFamily("NotoSans", 30);
  final textRenderer = TextRenderer(renderContext, notoSans, {
    "Noto Sans": notoSans,
    "CascadiaCode": cascadia,
  });

  final uiProjection = makeOrthographicMatrix(0, window.width.toDouble(), window.height.toDouble(), 0, -10, 10);
  final worldProjection = makePerspectiveMatrix(75 * degrees2Radians, window.width / window.height, 0.1, 2000);

  window.onResize.listen((event) {
    gl.viewport(0, 0, event.width, event.height);
    setOrthographicMatrix(uiProjection, 0, event.width.toDouble(), event.height.toDouble(), 0, -10, 10);
    setPerspectiveMatrix(worldProjection, 75 * degrees2Radians, event.width / event.height, 0.1, 2000);
  });

  var vSync = true;
  window.onKey.where((event) => event.key == glfwKeyV && event.action == glfwPress).listen((event) {
    glfw.swapInterval(vSync ? 0 : 1);
    vSync = !vSync;
  });

  // window.toggleFullscreen();
  window.onKey.where((event) => event.key == glfwKeyF11 && event.action == glfwPress).listen((event) {
    window.toggleFullscreen();
  });

  // spawning new isolates in the current isolate's group may well
  // cause the current isolate to continue execution on a different
  // thread after crossing the async gap. to avoid losing the thread-local opengl
  // context, we release the binding before spawning the isolates
  // and reacquire it after (potentially now on a different thread)
  //
  // glisco, 29.03.2024
  glfw.makeContextCurrent(nullptr);
  final (chunkCompilers, chunkGenWorkers) = await (
    createChunkCompileWorkers(min(Platform.numberOfProcessors ~/ 2, 8)),
    createChunkGenWorkers(min(Platform.numberOfProcessors ~/ 2, 8))
  ).wait;
  glfw.makeContextCurrent(window.handle);

  final world = World();
  final tags = TagManager();
  world.addManager(tags);
  world.addManager(ChunkManager());

  if (!args.wasParsed('debug-camera')) {
    world.addSystem(CameraControlSystem(InputProvider(window)), group: renderGroup);
  } else {
    world.addSystem(DebugCameraMovementSystem(), group: renderGroup);
    window.onKey.where((event) => event.key == glfwKeyP && event.action == glfwPress).listen((event) {
      DebugCameraMovementSystem.move = !DebugCameraMovementSystem.move;
    });
  }

  world.addSystem(ChunkRenderSystem(renderContext, chunkCompilers), group: renderGroup);
  world.addSystem(ChunkLoadingSystem(chunkGenWorkers), group: logicGroup);
  world.addSystem(VelocitySystem(), group: logicGroup);
  world.addSystem(AirDragSystem(), group: logicGroup);
  world.chunks = ChunkStorage();

  world.initialize();

  tags.register(
    world.createEntity([
      Position(x: 0, y: 48, z: 0),
      Velocity(),
      Orientation(pitch: -90 * degrees2Radians),
      CameraConfiguration(),
    ]),
    "active_camera",
  );

  // world.chunks.generate(chunkGenWorkers, 12, 4);
  // iterateRingColumns(12, 4, (chunkPos) {
  //   world.createEntity([
  //     Position(
  //       x: Chunk.size * chunkPos.x.toDouble(),
  //       y: Chunk.size * chunkPos.y.toDouble(),
  //       z: Chunk.size * chunkPos.z.toDouble(),
  //     ),
  //     ChunkDataComponent(chunkPos),
  //     ChunkMeshComponent(),
  //   ]);
  // });

  final cameraMapper = Mapper<CameraConfiguration>(world), posMapper = Mapper<Position>(world);

  var grabbed = false;
  window.onKey.where((event) => event.key == glfwKeyT && event.action == glfwPress).listen((event) {
    glfw.setInputMode(window.handle, glfwCursor, grabbed ? glfwCursorNormal : glfwCursorDisabled);
    grabbed = !grabbed;
  });

  window.onKey.where((event) => event.key == glfwKeyR && event.action == glfwPress).listen((event) {
    for (final mesh in world.componentManager
        .getComponentsByType<ChunkMeshComponent>(ComponentType.getTypeFor(ChunkMeshComponent))) {
      mesh.state = ChunkMeshState.empty;
    }
  });

  window.onMouseButton
      .where((event) => event.button == glfwMouseButtonRight && event.action == glfwPress)
      .listen((event) {
    final cameraPos = posMapper[tags.getEntity('active_camera')!];
    final cameraBlockPos = DiscretePosition(cameraPos.x.toInt(), cameraPos.y.toInt(), cameraPos.z.toInt());

    final cameraChunkPos = ChunkStorage.worldPosToChunkPos(cameraBlockPos);
    final chunk = world.chunks.chunkAt(cameraChunkPos);

    if (chunk is! EmptyChunk) {
      chunk[Chunk.worldPosToLocalPos(cameraBlockPos)] = 1;
      world.componentManager
          .getComponent<ChunkMeshComponent>(world.getManager<ChunkManager>().entityForChunk(cameraChunkPos)!,
              ComponentType.getTypeFor(ChunkMeshComponent))!
          .state = ChunkMeshState.empty;
    }
  });

  final chyzTexture = loadTexture("chyzman");
  final chyz = loadObj(File("resources/chyzman.obj"));
  final chyzBuffer = MeshBuffer(terrainVertexDescriptor, renderContext.findProgram("terrain"));
  for (final Tri(:vertices, :normals, :uvs) in chyz.tris) {
    chyzBuffer.vertex(
      chyz.vertices[vertices.$1 - 1] + Vector3(8, .5, 8),
      chyz.normals[normals.$1 - 1],
      chyz.uvs[uvs.$1 - 1].x,
      1 - chyz.uvs[uvs.$1 - 1].y,
    );
    chyzBuffer.vertex(
      chyz.vertices[vertices.$2 - 1] + Vector3(8, .5, 8),
      chyz.normals[normals.$2 - 1],
      chyz.uvs[uvs.$2 - 1].x,
      1 - chyz.uvs[uvs.$2 - 1].y,
    );
    chyzBuffer.vertex(
      chyz.vertices[vertices.$3 - 1] + Vector3(8, .5, 8),
      chyz.normals[normals.$3 - 1],
      chyz.uvs[uvs.$3 - 1].x,
      1 - chyz.uvs[uvs.$3 - 1].y,
    );
  }
  chyzBuffer.upload();

  final skyBuffer = MeshBuffer(posColorVertexDescriptor, renderContext.findProgram("gui_pos_color"));
  skyBuffer
    ..vertex(Vector3(-1, 1, .9995), Color.ofRgb(0xFFF3C7))
    ..vertex(Vector3(-1, -1, .9995), Color.ofRgb(0x78a7ff))
    ..vertex(Vector3(1, 1, .9995), Color.ofRgb(0xFFF3C7))
    ..vertex(Vector3(-1, -1, .9995), Color.ofRgb(0x78a7ff))
    ..vertex(Vector3(1, -1, .9995), Color.ofRgb(0x78a7ff))
    ..vertex(Vector3(1, 1, .9995), Color.ofRgb(0xFFF3C7))
    ..upload();

  final crosshairTexture = loadTexture("crosshair");
  final crosshairBuffer = MeshBuffer(posUvColorVertexDescriptor, renderContext.findProgram("gui_pos_uv_color"));
  crosshairBuffer
    ..vertex(Vector3(0, 0, 0), 0, 0, Color.white)
    ..vertex(Vector3(0, 15, 0), 0, 1, Color.white)
    ..vertex(Vector3(15, 0, 0), 1, 0, Color.white)
    ..vertex(Vector3(0, 15, 0), 0, 1, Color.white)
    ..vertex(Vector3(15, 15, 0), 1, 1, Color.white)
    ..vertex(Vector3(15, 0, 0), 1, 0, Color.white)
    ..upload();

  var frames = 0, lastFps = 0;
  var ticks = 0, lastTicks = 0;
  var lastTime = glfw.getTime(), passedTime = 0.0;
  var logicTimer = 0.0;

  final fb = GlFramebuffer.trackingWindow(window);

  renderContext.findProgram('terrain').uniform4vf('uFogColor', Color.white.asVector());
  renderContext.findProgram('terrain').uniform1f('uFogStart', 175);
  renderContext.findProgram('terrain').uniform1f('uFogEnd', 250);

  renderContext.findProgram('terrain').uniformSampler('uSky', fb.colorAttachment, 1);
  renderContext.findProgram('terrain').uniform2f('uSkySize', window.width.toDouble(), window.height.toDouble());
  window.onResize.listen((event) {
    renderContext.findProgram('terrain').uniformSampler('uSky', fb.colorAttachment, 1);
    renderContext.findProgram('terrain').uniform2f('uSkySize', event.width.toDouble(), event.height.toDouble());
  });

  while (glfw.windowShouldClose(window.handle) != glfwTrue) {
    // execute scheduled microtasks
    await Future.delayed(Duration.zero);
    // gl.enable(glCullFace);

    gl.clearColor(0, 0, 0, 0);
    gl.clear(glColorBufferBit | glDepthBufferBit | glStencilBufferBit);
    gl.enable(glBlend);
    gl.enable(glDepthTest);

    TriCount.triCount = 0;
    fb.bind();
    fb.clear(color: Color.ofArgb(0), depth: 1);

    var delta = glfw.getTime() - lastTime;
    lastTime = glfw.getTime();

    logicTimer += delta;
    while (logicTimer > 1 / tickRate) {
      logicTimer -= 1 / tickRate;

      world.delta = 1 / tickRate;
      world.process(logicGroup);

      ticks++;
    }

    skyBuffer.program.uniformMat4("uProjection", Matrix4.identity());
    skyBuffer.program.uniformMat4("uTransform", Matrix4.identity());
    skyBuffer.program.use();
    skyBuffer.draw();

    fb.unbind();
    gl.blitNamedFramebuffer(
      fb.fbo,
      0,
      0,
      0,
      fb.width,
      fb.height,
      0,
      0,
      fb.width,
      fb.height,
      glColorBufferBit | glDepthBufferBit,
      glNearest,
    );

    final camera = cameraMapper[tags.getEntity("active_camera")!];
    final viewMatrix = camera.computeViewMatrix(posMapper[tags.getEntity("active_camera")!]);

    world.delta = delta;
    world.properties["view_matrix"] = viewMatrix;
    world.properties["world_projection"] = worldProjection;
    world.process(renderGroup);

    chyzBuffer.program.uniformMat4("uProjection", worldProjection);
    chyzBuffer.program.uniformMat4("uView", viewMatrix);
    chyzBuffer.program.uniform3f("uOffset", 0, 0, 0);
    chyzBuffer.program.uniformSampler("uTexture", chyzTexture, 0);
    chyzBuffer.program.use();
    chyzBuffer.drawAndCount();

    gl.clear(glDepthBufferBit);

    gl.blendFunc(glOneMinusDstColor, glOneMinusSrcColor);

    crosshairBuffer.program.uniformMat4("uProjection", uiProjection);
    crosshairBuffer.program.uniformMat4(
        "uTransform",
        Matrix4.identity()
          ..scale(2.0, 2.0, 1.0)
          ..translate(((window.width - 15) ~/ 4).toDouble(), ((window.height - 15) ~/ 4).toDouble(), 0));
    crosshairBuffer.program.uniformSampler("uTexture", crosshairTexture, 0);
    crosshairBuffer.program.use();
    crosshairBuffer.draw();

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);

    String compact(Vector values) => values.storage.map((e) => e.toStringAsFixed(3)).join(", ");
    textRenderer.drawText(
        5, window.height - 145, Text.string("Entities: ${world.entityManager.activeEntityCount}"), 16, uiProjection,
        color: Color.black);
    textRenderer.drawText(
        5, window.height - 125, Text.string("Speed: ${camera.speed.toStringAsFixed(3)}"), 16, uiProjection,
        color: Color.black);
    textRenderer.drawText(5, window.height - 105, Text.string("TPS: $lastTicks"), 16, uiProjection, color: Color.black);
    textRenderer.drawText(
        5, window.height - 85, Text.string("FPS: $lastFps (${vSync ? "v-sync" : "uncapped"})"), 16, uiProjection,
        color: Color.black);
    textRenderer.drawText(5, window.height - 65, Text.string("Triangles: ${TriCount.triCount}"), 16, uiProjection,
        color: Color.black);
    textRenderer.drawText(5, window.height - 45, Text.string("Forward: ${compact(camera.forward)}"), 16, uiProjection,
        color: Color.black);
    textRenderer.drawText(5, window.height - 25,
        Text.string("Pos: ${compact(posMapper[tags.getEntity("active_camera")!].value)}"), 16, uiProjection,
        color: Color.black);

    window.nextFrame();

    if (passedTime >= 1) {
      lastFps = frames;
      frames = 0;
      lastTicks = ticks;
      ticks = 0;
      passedTime -= 1;
    }

    passedTime += delta;
    frames++;
  }

  glfw.terminate();

  chunkCompilers.shutdown();
  chunkGenWorkers.shutdown();
}

ArgParser setupArgs() {
  final parser = ArgParser();
  parser.addFlag('debug-camera', help: 'Disable normal user input in favor of debug camera movement', negatable: false);
  parser.addFlag('help', help: 'Print this usage information', negatable: false);

  return parser;
}

void onGlfwError(int errorCode, Pointer<Char> description) {
  _glfwLogger.severe("GLFW Error: ${description.cast<Utf8>().toDartString()} ($errorCode)");
}

Future<GlProgram> vertFragProgram(String name, String vert, String frag) async {
  final shaders = await Future.wait([
    GlShader.fromFile(File("resources/shader/$vert.vert"), GlShaderType.vertex),
    GlShader.fromFile(File("resources/shader/$frag.frag"), GlShaderType.fragment),
  ]);

  return GlProgram(name, shaders);
}
