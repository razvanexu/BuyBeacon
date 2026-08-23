import 'dart:async';
import 'dart:developer';

import 'package:buy_beacon/models/category_option.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/screens/map_screen.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  //Controller to get the text from the input field
  final TextEditingController _textController = TextEditingController();

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  StreamSubscription? _orchestratorSubscription;
  LocationService? _locationService;

  // Dismissed for the current session only -- if the OEM health check still
  // reports the app isn't whitelisted next time the app is opened, the
  // banner reappears rather than being silenced forever.
  bool _powerManagerBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orchestratorSubscription == null) {
      final orchestrator = Provider.of<ShoppingOrchestrator>(context, listen: false);

      if (orchestrator.currentState.hasConnectionError) {
        _showConnectionErrorSnackbar();
      }

      _orchestratorSubscription = orchestrator.onStateChanged.listen(_handleStateChange);
      log('_handleStateChange called');
    }

    _locationService ??= Provider.of<LocationService>(context, listen: false)
      ..addListener(_handlePowerManagerPromptChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have just come back from the OEM settings screen opened
    // via showPowerManager() -- re-check so the banner clears itself if
    // they whitelisted the app.
    if (state == AppLifecycleState.resumed) {
      _locationService?.refreshSettingsHealth();
    }
  }

  void _handlePowerManagerPromptChanged() {
    if (!_locationService!.needsPowerManagerPrompt) {
      _powerManagerBannerDismissed = false;
    }
    if (mounted) setState(() {});
  }

  void _handleStateChange(ShoppingState state) {
    log('--- _handleStateChange ---');
    log('Received state: hasConnectionError = ${state.hasConnectionError}');
    if (state.hasConnectionError) {
      log(
        'Condition state.hasConnectionError is TRUE. Calling _showConnectionErrorSnackbar...',
      );
      _showConnectionErrorSnackbar();
      log('Condition state.hasConnectionError is FALSE.');
    }
  }

  void _showConnectionErrorSnackbar() {
    log('_showConnectionErrorSnackbar called');
    _scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Connection error. Please check your internet connection.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _locationService?.removeListener(_handlePowerManagerPromptChanged);
    WidgetsBinding.instance.removeObserver(this);
    _orchestratorSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  //UI Builder methods
  @override
  Widget build(BuildContext context) {
    final orchestrator = Provider.of<ShoppingOrchestrator>(context, listen: false);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BuyBeacon'),
          actions: [
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
            ),
          ],
          //progress indicator
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: StreamBuilder<ShoppingState>(
              stream: orchestrator.onStateChanged,
              initialData: orchestrator.currentState,
              builder: (context, snapshot) {
                final isLoading = snapshot.data?.isLoading ?? false;
                return isLoading
                    ? const LinearProgressIndicator()
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
        body: Column(
          children: [
            if (_locationService?.needsPowerManagerPrompt == true &&
                !_powerManagerBannerDismissed)
              _buildPowerManagerBanner(),
            _buildProductInput(),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerManagerBanner() {
    return MaterialBanner(
      content: const Text(
        'Your phone\'s manufacturer may kill BuyBeacon in the background, stopping '
        'notifications. Battery settings alone often aren\'t enough -- also enable '
        '"Autostart" and lock the app in Recent Apps.',
      ),
      leading: const Icon(Icons.battery_alert),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _powerManagerBannerDismissed = true);
          },
          child: const Text('Dismiss'),
        ),
        TextButton(
          onPressed: () => _locationService?.openPowerManager(),
          child: const Text('Fix settings'),
        ),
      ],
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
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                _addProduct();
              },
            ),
          ),
          const SizedBox(width: 16.0),
          ElevatedButton(
            onPressed: () {
              _addProduct();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
            ),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    // The Consumer widget listens for changes in ProductProvider
    // and rebuilds the ListView whenever notifyListeners() is called.
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (!provider.isInitialized) {
          return const Expanded(child: Center(child: CircularProgressIndicator()));
        } else if (provider.products.isEmpty) {
          return const Expanded(
            child: Center(child: Text('Your shopping list is empty.')),
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
                    try {
                      Provider.of<ProductProvider>(
                        context,
                        listen: false,
                      ).deleteProduct(product.id!);
                    } catch (e, s) {
                      log(
                        'Error deleting product',
                        name: 'HomeScreen',
                        error: e,
                        stackTrace: s,
                      );
                    }
                    // Call the provider's delete method
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _addProduct() async {
    log('[1] _addProduct called.', name: 'HomeScreen');
    final name = _textController.text;
    if (name.isEmpty) {
      log('[!] Text field is empty. Aborting.', name: 'HomeScreen');
      return;
    }
    try {
      log('[2] Getting ProductProvider.', name: 'HomeScreen');
      final provider = Provider.of<ProductProvider>(context, listen: false);

      log('[3] Looking up category for "$name".', name: 'HomeScreen');
      final category = await provider.lookupCategory(name);

      if (category != null) {
        log('[4] Category known ("$category"). Adding product directly.', name: 'HomeScreen');
        await provider.addProduct(name);
      } else {
        log('[4] Category unknown. Prompting user to pick one.', name: 'HomeScreen');
        if (!mounted) return;
        final options = await provider.getCategoryOptions();
        if (!mounted) return;
        final selected = await _showCategoryPicker(context, options);
        if (selected != null) {
          await provider.addProductWithCategory(name, selected.code);
        } else {
          log('[!] User dismissed category picker without selecting.', name: 'HomeScreen');
          return;
        }
      }

      log('[5] Clearing text controller.', name: 'HomeScreen');
      _textController.clear();
    } catch (e, s) {
      log(
        '[!] CRITICAL ERROR in _addProduct.',
        name: 'HomeScreen',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<CategoryOption?> _showCategoryPicker(
    BuildContext context,
    List<CategoryOption> options,
  ) {
    return showDialog<CategoryOption>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Ce fel de magazin vinde acest produs?'),
          children: options
              .map(
                (option) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, option),
                  child: Text(option.label),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
