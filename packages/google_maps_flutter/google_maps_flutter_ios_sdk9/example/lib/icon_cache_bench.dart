// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

// Benchmark for the marker icon cache. Not part of the upstream change.
//
// Shows 1000 markers with six distinct byte icons, then replaces all of them
// (new IDs, shifted positions) a number of times. The native side logs the
// time of each marker batch and the part of it spent on icons as
// `[IconCacheBench]` lines. Launch the app with `-IconCacheBenchDisabled YES`
// to measure the same batches without the cache.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'example_google_map.dart';

const int _markerCount = 1000;
const int _replacements = 10;
const LatLng _center = LatLng(50.08, 14.42);

class IconCacheBenchPage extends StatefulWidget {
  const IconCacheBenchPage({super.key});

  @override
  State<IconCacheBenchPage> createState() => _IconCacheBenchPageState();
}

class _IconCacheBenchPageState extends State<IconCacheBenchPage> {
  Set<Marker> _markers = <Marker>{};
  String _status = 'Waiting for the map';

  Future<void> _run() async {
    final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final icons = <BitmapDescriptor>[
      for (final color in <Color>[
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.orange,
        Colors.purple,
        Colors.grey,
      ])
        BytesMapBitmap(await _pinBytes(color, pixelRatio), imagePixelRatio: pixelRatio),
    ];
    // Round 0 is the first load; rounds 1 to _replacements replace every marker.
    for (var round = 0; round <= _replacements; round++) {
      setState(() {
        _status = 'Round $round of $_replacements';
        _markers = <Marker>{
          for (var i = 0; i < _markerCount; i++)
            Marker(
              markerId: MarkerId('r${round}_m$i'),
              position: LatLng(
                _center.latitude + (i ~/ 40) * 0.004 + round * 0.0001,
                _center.longitude + (i % 40) * 0.006,
              ),
              icon: icons[i % icons.length],
            ),
        };
      });
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    setState(() => _status = 'Done');
  }

  /// A 24x32 logical pixel pin in [color], as PNG bytes at [pixelRatio].
  Future<Uint8List> _pinBytes(Color color, double pixelRatio) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    canvas.drawCircle(const Offset(12, 12), 11, Paint()..color = color);
    canvas.drawRect(const Rect.fromLTWH(11, 20, 2, 12), Paint()..color = color);
    final ui.Image image = await recorder.endRecording().toImage(
      (24 * pixelRatio).round(),
      (32 * pixelRatio).round(),
    );
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Icon cache bench: $_status')),
      body: ExampleGoogleMap(
        initialCameraPosition: const CameraPosition(target: _center, zoom: 11),
        markers: _markers,
        onMapCreated: (_) =>
            Future<void>.delayed(const Duration(seconds: 3)).then((_) => _run()),
      ),
    );
  }
}
