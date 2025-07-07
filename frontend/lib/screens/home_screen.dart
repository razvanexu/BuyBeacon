
import 'dart:developer';

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
              onSubmitted: (value) {
                _addProduct();
              },
            ),
          ),
          const SizedBox(width: 16.0,),
          ElevatedButton(
              onPressed: () {
                //TODO: logic for adding product
                _addProduct();
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
                            try{
                              Provider.of<ProductProvider>(context, listen: false)
                                  .deleteProduct(product.id!);
                            }catch(e, s){
                              log('Error deleting product', name: 'HomeScreen', error: e, stackTrace: s);
                            }
                            // Call the provider's delete method
                          },
                        )
                    );
                  }
              )
          );
        }
    );
  }

  void _addProduct() {
    log('[1] _addProduct called.', name: 'HomeScreen');
    if (_textController.text.isEmpty) {
        log('[!] Text field is empty. Aborting.', name: 'HomeScreen');
        return;
      }
    try {
        log('[2] Getting ProductProvider.', name: 'HomeScreen');
        // We get the provider here, inside the try-catch block.
        final provider = Provider.of<ProductProvider>(context, listen: false);
        log('[3] ProductProvider found. Calling provider.addProduct().', name: 'HomeScreen');
          // We call the provider's method, which is an async Future.
        // We don't need to `await` it here, but we catch potential errors.
        provider.addProduct(_textController.text).catchError((e, s) {
             log('[!] Error during provider.addProduct() future.', name: 'HomeScreen', error: e, stackTrace: s);
          });
          log('[4] Clearing text controller.', name: 'HomeScreen');
        _textController.clear();
        } catch (e, s) {
        // This will catch an error if Provider.of fails or if any other synchronous error occurs.
        log('[!] CRITICAL ERROR in _addProduct.', name: 'HomeScreen', error: e, stackTrace: s);
      }
  }
}