import 'dart:html';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:web_gl' as gl;

import 'package:glutils/glutils.dart';
import 'package:vector_math/vector_math.dart';
import 'package:http/browser_client.dart' as http;

Future main() async {
  final client = new http.BrowserClient();

  // Load data.
  final response = await client.get('data.json');
  final List<List<num>> rawData = JSON.decode(response.body);

  // Find number of frames.
  final frameCount =
      rawData.fold(0, (int count, row) => max(count, row[5].toInt())) + 1;

  // Create particle buffer for each frame.
  final frames = new List<List<Vector3>>(frameCount);
  for (final r in rawData) {
    // Add particle to given frame.
    frames[r[5].toInt()] ??= new List<Vector3>();
    frames[r[5].toInt()].add(new Vector3(r[1], r[2], r[3]));
  }

  // Copy frames into typed arrays.
  final typedFrames = new List<Float32List>.generate(frames.length, (i) {
    final data = new Float32List(frames[i].length * 3);
    var offset = 0;
    for (final v in frames[i]) {
      v.copyIntoArray(data, offset);
      offset += 3;
    }
    return data;
  });

  // Setup rendering.
  final CanvasElement canvas = querySelector('#canvas');
  final renderer = new FlyRenderer(canvas, typedFrames);

  // Handle window resize.
  void resizeCanvas() {
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
    renderer.updateViewport();
  }

  resizeCanvas();
  window.onResize.listen((_) => resizeCanvas());

  // Compute bounding box.
  final minV = frames[0][0].clone();
  final maxV = frames[0][0].clone();
  for (final frame in frames) {
    for (final v in frame) {
      Vector3.min(minV, v, minV);
      Vector3.max(maxV, v, maxV);
    }
  }

  // Foxus at bounding box and start.
  renderer.focus(new Aabb3.minMax(minV, maxV));
  renderer.start();

  // TODO: make clipping depths configurable in glutils.
}

class FlyRenderer extends GlCanvas {
  GlObject particleSystem;
  GlShader particleShader;
  GlBuffer<Float32List> particleData;
  final List<Float32List> frames;
  var frameIndex = 0;

  FlyRenderer(CanvasElement canvas, this.frames) : super(canvas) {
    // Compile particle shader.
    particleShader = new GlShader(ctx, _vertexShader, _fragmentShader,
        ['aParticlePosition'], ['uViewMatrix']);
    particleShader.positionAttrib = 'aParticlePosition';
    particleShader.viewMatrix = 'uViewMatrix';
    particleShader.compile();

    // Setup particle system.
    particleSystem = new GlObject(ctx);
    particleSystem.shaderProgram = particleShader;

    // Setup particle data buffer.
    particleData = new GlBuffer<Float32List>(ctx);
    particleData.link('aParticlePosition', gl.FLOAT, 3, 0, 0);
    particleSystem.buffers.add(particleData);
  }

  @override
  void draw(num time, Matrix4 viewMatrix) {
    // Move to next frame.
    frameIndex++;
    if (frameIndex >= frames.length) {
      frameIndex = 0;
    }

    // Update frame data.
    particleData.update(frames[frameIndex]);

    // Transform the particle system using viewMatrix.
    particleSystem.transform = viewMatrix;

    // Set uniforms.
    particleShader.use();
    /*ctx.uniform1f(particleShader.uniforms['uViewportRatio'],
        viewportWidth / viewportHeight);*/

    particleSystem.drawArrays(
        gl.POINTS, (frames[frameIndex].length / 3).floor());
  }
}

const _vertexShader = '''
attribute vec3 aParticlePosition;
uniform mat4 uViewMatrix;

void main() {
  gl_Position = uViewMatrix * vec4(aParticlePosition, 1.0);
  gl_PointSize = 4.0;
}
''';

const _fragmentShader = '''
precision mediump float;

void main() {
  gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
''';
