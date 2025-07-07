class Product{
  final int? id;
  final String name;

  Product({this.id, required this.name});

  factory Product.fromMap(Map<String, dynamic> map){
    return Product(
      id: map['id'],
        name: map['name']
    );
  }

  Map<String, dynamic> toMap(){
    return {
      'id': id,
      'name': name
    };
  }
}