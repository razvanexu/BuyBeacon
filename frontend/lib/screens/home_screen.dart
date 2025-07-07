
import 'package:flutter/material.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //Controller to get the text from the input field
  final TextEditingController _textController = TextEditingController();

  //dummy list for design purposes
  //this will come from our local db in the future
  // final List<String> _products = [
  //   'Printer Ink',
  //   'Perla Coffee',
  //   'Craft supplies'
  // ];

  //UI Builder methids
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BuyBeacon'),
      ),
      body: Column(
        children: [
          _buildProductInput(),
          _buildProductList()
        ],
      ),
    );
  }

//input field and the "Add button
  Widget _buildProductInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                  labelText: 'Add product',
                  border: OutlineInputBorder()
              ),
            ),
          ),
          const SizedBox(width: 16.0,),
          ElevatedButton(
              onPressed: () {
                //TODO: logic for adding product
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Icon(Icons.add))
        ],
      ),
    );
  }

  Widget _buildProductList() {
    // The Consumer widget listens for changes in ProductProvider
    // and rebuilds the ListView whenever notifyListeners() is called.
    return Consumer<ProductProvider>(
        builder: (context, provider, child){
          if(provider.products.isEmpty){
            return const Expanded(
                child: Center(
                  child: Text('Your shopping list is empty.')
                )
            );
          }
          return Expanded(
              child: ListView.builder(
                  itemCount: provider.products.length,
                  itemBuilder: (context, index) {
                    final product = provider.products[index];
                    return ListTile(
                        title: Text(product.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            // Call the provider's delete method
                            provider.deleteProduct(product.id!);
                          },
                        )
                    );
                  }
              )
          );
        }
    );
  }

  void addProduct(ProductProvider provider){
    if(_textController.text.isNotEmpty){
      provider.addProduct(_textController.text);
      _textController.clear();
    }
  }
}