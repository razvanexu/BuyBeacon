class CategoryOption {
  final String code;
  final String label;

  CategoryOption({required this.code, required this.label});

  factory CategoryOption.fromMap(Map<String, dynamic> map) {
    return CategoryOption(code: map['value'] as String, label: map['label'] as String);
  }
}
