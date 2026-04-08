import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String label;
  final String? iconUrl;

  CategoryModel({
    required this.id,
    required this.label,
    this.iconUrl,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      label: data['label'] ?? '',
      iconUrl: data['iconUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'iconUrl': iconUrl,
    };
  }
}
