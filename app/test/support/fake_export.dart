import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/domain/engine/roll_engine.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/export/data/export_destinations.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/models/export_models.dart';
import 'package:lastreel/features/export/render/frame_source.dart';

/// An encoder that keeps what it's given. Each frame takes [frameTime] of
/// (fake) time, so a render can be watched in progress.
class FakeVideoEncoder implements VideoEncoder {
  EncoderCapabilities caps;
  Duration frameTime;

  /// Fail with this at frame [failAtFrame].
  EncoderException? failWith;
  int failAtFrame;

  final List<EncodeSpec> started = [];
  int appended = 0;
  int cancelled = 0;

  static const everything = EncoderCapabilities({
    Codec.h264: 3840,
    Codec.hevc: 3840,
    Codec.prores422: 3840,
    Codec.prores4444: 3840,
    Codec.png: 8192,
  });

  /// What an Android phone offers: no ProRes, and HEVC only to 1920.
  static const android = EncoderCapabilities({Codec.h264: 3840, Codec.hevc: 1920, Codec.png: 8192});

  FakeVideoEncoder({
    this.caps = everything,
    this.frameTime = const Duration(milliseconds: 20),
    this.failWith,
    this.failAtFrame = 0,
  });

  @override
  Future<EncoderCapabilities> capabilities() async => caps;

  @override
  Future<EncodeSession> start(EncodeSpec spec) async {
    started.add(spec);
    return _FakeSession(this, spec);
  }
}

class _FakeSession implements EncodeSession {
  final FakeVideoEncoder _encoder;
  final EncodeSpec _spec;
  int _frames = 0;

  _FakeSession(this._encoder, this._spec);

  @override
  Future<void> append(ui.Image frame, int index) async {
    await Future<void>.delayed(_encoder.frameTime);
    if (_encoder.failWith case final failure? when index >= _encoder.failAtFrame) {
      _encoder.failWith = null;
      throw failure;
    }
    assert(index == _frames, 'frames arrive in order');
    _frames++;
    _encoder.appended++;
  }

  @override
  Future<EncodedFile> finish() async => EncodedFile(_spec.outputPath, _frames * 1000);

  @override
  Future<void> cancel() async => _encoder.cancelled++;
}

/// Frames without drawing anything: a render of [frames] tiny images.
class FakeFrameSource implements FrameSource {
  @override
  final int frameCount;
  bool disposed = false;

  FakeFrameSource(this.frameCount);

  @override
  Future<ui.Image> render(int index) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
    return recorder.endRecording().toImageSync(2, 2);
  }

  @override
  void dispose() => disposed = true;
}

/// Opens [FakeFrameSource]s of [frames] frames, noting each output size.
class FakeFrames {
  final int frames;
  final List<(int, int)> opened = [];

  FakeFrames({this.frames = 48});

  Future<FrameSource> open({
    required ProjectSettings settings,
    required List<CreditBlock> blocks,
    required RollGeometry geometry,
    required int outputWidth,
    required int outputHeight,
  }) async {
    opened.add((outputWidth, outputHeight));
    return FakeFrameSource(frames);
  }
}

class FakeExportDestinations implements ExportDestinations {
  final List<String> shared = [];
  final List<String> savedToPhotos = [];

  @override
  Future<Result<void>> saveToPhotos(String path) async {
    savedToPhotos.add(path);
    return const Ok(null);
  }

  @override
  Future<Result<void>> share(String path, {ui.Rect? origin}) async {
    shared.add(path);
    return const Ok(null);
  }
}

/// An ad service whose rewarded ad ends however the test says.
class FakeAdService implements AdService {
  RewardOutcome nextReward;
  int rewardedShown = 0;
  bool privacyRequired;

  FakeAdService({this.nextReward = RewardOutcome.earned, this.privacyRequired = false});

  @override
  Widget nativeAd(AdPlacement placement) => const PlaceholderAdService().nativeAd(placement);

  @override
  Future<RewardOutcome> showRewarded() async {
    rewardedShown++;
    return nextReward;
  }

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {}
}
