
import 'package:flutter/material.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';

void main(){
  runApp(
    ChangeNotifierProvider(
        create: (context) => ProductProvider(),
        child: const BuyBeaconApp())
  );
}

class BuyBeaconApp extends StatelessWidget{
  const BuyBeaconApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'BuyBeacon',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity
      ),
      home: const HomeScreen(),
    );
  }
}