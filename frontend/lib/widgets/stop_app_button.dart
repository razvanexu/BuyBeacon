import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class StopAppButton extends StatefulWidget {
  const StopAppButton({super.key});

  @override
  State<StopAppButton> createState() => _StopAppButtonState();
}

class _StopAppButtonState extends State<StopAppButton> {
  bool _stopping = false;

  Future<void> _onPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Oprești BuyBeacon?'),
        content: const Text(
          'Localizarea și notificările se opresc și aplicația se închide. '
          'Pornesc din nou când redeschizi aplicația.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Oprește'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _stopping = true);
    final orchestrator = Provider.of<ShoppingOrchestrator>(context, listen: false);
    await orchestrator.shutdown();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.power_settings_new),
      tooltip: 'Oprește BuyBeacon',
      onPressed: _stopping ? null : _onPressed,
    );
  }
}
