import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Reads map tiles from a pre-bundled .mbtiles file (SQLite database).
// MBTiles spec: tiles stored as PNG/JPG blobs keyed by (zoom, x, y).
// The Y axis is flipped vs XYZ convention — we correct that below.

class MapService {
  static Database? _db;

  // Call once at app startup — copies asset to writable storage on first run
  static Future<void> init({String assetPath = 'assets/maps/csn_map.mbtiles'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/csn_map.mbtiles';

    if (!File(dbPath).existsSync()) {
      final data = await rootBundle.load(assetPath);
      await File(dbPath)
          .writeAsBytes(data.buffer.asUint8List(), flush: true);
    }

    _db = await openDatabase(dbPath, readOnly: true);
  }

  static MBTilesTileProvider get tileProvider {
    assert(_db != null, 'Call MapService.init() before using tileProvider');
    return MBTilesTileProvider(_db!);
  }
}

// ── Custom TileProvider for flutter_map ─────────────────────────────────────

class MBTilesTileProvider extends TileProvider {
  final Database _db;
  MBTilesTileProvider(this._db);

  @override
  ImageProvider getImage(TileCoordinates coords, TileLayer options) {
    // MBTiles uses TMS Y (flipped) — convert from XYZ
    final tmsY = (1 << coords.z) - 1 - coords.y.toInt();
    return _MBTilesImageProvider(
      db: _db,
      z: coords.z,
      x: coords.x.toInt(),
      y: tmsY,
    );
  }
}

class _MBTilesImageProvider extends ImageProvider<_MBTilesImageProvider> {
  final Database db;
  final int z, x, y;
  const _MBTilesImageProvider({
    required this.db,
    required this.z,
    required this.x,
    required this.y,
  });

  @override
  Future<_MBTilesImageProvider> obtainKey(ImageConfiguration config) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _MBTilesImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final rows = await db.rawQuery(
      'SELECT tile_data FROM tiles '
      'WHERE zoom_level=? AND tile_column=? AND tile_row=?',
      [z, x, y],
    );
    if (rows.isEmpty) {
      // Return a transparent 1×1 tile for missing areas
      return ImageInfo(image: await _transparentTile());
    }
    final bytes = rows.first['tile_data'] as Uint8List;
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  Future<Image> _transparentTile() async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, 256, 256),
      Paint()..color = const Color(0x00000000),
    );
    return recorder.endRecording().toImage(256, 256);
  }

  @override
  bool operator ==(Object other) =>
      other is _MBTilesImageProvider &&
      z == other.z &&
      x == other.x &&
      y == other.y;

  @override
  int get hashCode => Object.hash(z, x, y);
}
