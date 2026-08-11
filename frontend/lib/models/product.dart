import 'package:diacritic/diacritic.dart';

class Product {
  final int? id;
  final String name;

  Product({this.id, required this.name});

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(id: map['id'], name: map['name']);
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  static String normalizeName(String input) {
    String normalized = removeDiacritics(input);
    final RegExp trimEdges = RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true);

    final cleaned = normalized
        .trim() // elimină spațiile de la început și sfârșit
        .split(RegExp(r'\s+')) // împarte după unul sau mai multe spații
        .map((word) => word.replaceAll(trimEdges, '')) // curăță fiecare cuvânt
        .where((word) => word.isNotEmpty) // elimină segmentele goale
        .join(' '); // reconstruiește fraza

    return cleaned;
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name}';
  }
}
