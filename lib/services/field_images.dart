import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FieldImages {
  static List<Field> fields = [];

  static Field? getFieldFromGame(String game) {
    if (fields.isEmpty) {
      return null;
    }

    Field field = fields.firstWhere((element) => element.game == game);

    field.instanceCounter++;
    if (!field.fieldImageLoaded) {
      field.loadFieldImage();
    }
    return field;
  }

  static bool hasField(String game) {
    return fields.map((e) => e.game).contains(game);
  }

  static Future loadFields(String directory) async {
    AssetManifest assetManifest =
        await AssetManifest.loadFromAssetBundle(rootBundle);

    List<String> filePaths = assetManifest
        .listAssets()
        .where((String key) => key.contains(directory) && key.contains('.json'))
        .toList();

    filePaths.sort();

    for (String file in filePaths.reversed) {
      await loadField(file);
    }
  }

  static Future loadField(String filePath) async {
    String jsonString = await rootBundle.loadString(filePath);

    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    fields.add(Field(jsonData: jsonData));
  }
}

class Field {
  final Map<String, dynamic> jsonData;

  late String? game;
  late String? sourceURL;

  int? fieldImageWidth;
  int? fieldImageHeight;

  late double fieldWidthMeters;
  late double fieldHeightMeters;

  late Offset topLeftCorner;
  late Offset bottomRightCorner;

  late Offset fieldCenter;

  late Image fieldImage;

  int instanceCounter = 0;
  bool fieldImageLoaded = false;

  late int pixelsPerMeterHorizontal;
  late int pixelsPerMeterVertical;

  Field({required this.jsonData}) {
    init();
  }

  void init() {
    fieldImageWidth = 3600;
    fieldImageHeight = 1400;

    game = jsonData['game'];
    sourceURL = jsonData['source-url'];

    fieldWidthMeters = jsonData['field-size'][0];
    fieldHeightMeters = jsonData['field-size'][1];

    topLeftCorner = Offset(
        (jsonData['field-corners']['top-left'][0] as int).toDouble(),
        (jsonData['field-corners']['top-left'][1] as int).toDouble());

    bottomRightCorner = Offset(
        (jsonData['field-corners']['bottom-right'][0] as int).toDouble(),
        (jsonData['field-corners']['bottom-right'][1] as int).toDouble());

    double fieldWidthPixels = bottomRightCorner.dx - topLeftCorner.dx;
    double fieldHeightPixels = bottomRightCorner.dy - topLeftCorner.dy;

    pixelsPerMeterHorizontal = (fieldWidthPixels / fieldWidthMeters).round();
    pixelsPerMeterVertical = (fieldHeightPixels / fieldHeightMeters).round();
  }

  void loadFieldImage() {
    fieldImage = Image.asset(jsonData['field-image']);
    fieldImage.image
        .resolve(ImageConfiguration.empty)
        .addListener(ImageStreamListener((image, synchronousCall) {
      fieldImageWidth = image.image.width;
      fieldImageHeight = image.image.height;

      fieldImageLoaded = true;
    }));
  }

  void dispose() async {
    instanceCounter--;
    if (instanceCounter <= 0) {
      await fieldImage.image.evict();
      imageCache.clear();
      fieldImageLoaded = false;
    }
  }
}
