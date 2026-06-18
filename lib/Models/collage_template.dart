import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_collage_widget/utils/collage_type.dart';

class CollageSlot {
  final double x;
  final double y;
  final double width;
  final double height;

  CollageSlot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory CollageSlot.fromJson(Map<String, dynamic> json) {
    return CollageSlot(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

class CollageTemplate {
  final CollageType type;
  final String icon;
  final String mask;
  final String jsonPath;
  List<CollageSlot> slots;
  int imageCount;

  CollageTemplate({
    required this.type,
    required this.icon,
    required this.mask,
    required this.jsonPath,
    this.slots = const [],
    this.imageCount = 0,
  });

  Future<void> loadSlots() async {
    try {
      final String data = await rootBundle.loadString(jsonPath);
      final Map<String, dynamic> jsonMap = json.decode(data);
      imageCount = jsonMap['imageCount'] ?? (jsonMap['slots'] as List).length;
      final List<dynamic> slotsJson = jsonMap['slots'];
      slots = slotsJson.map((s) => CollageSlot.fromJson(s)).toList();
    } catch (e) {
      debugPrint("Error loading slots for $jsonPath: $e");
    }
  }
}
