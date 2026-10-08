import 'package:flutter/material.dart';

import '../arylic/arylic_discovery.dart';
import '../controller/radio_controller.dart';
import 'theme.dart';

Future<void> showAmpSheet(BuildContext context, RadioController controller) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AmpSheet(controller: controller),
    );

/// Find, connect and control an Arylic amp (Up2Stream Amp and other
/// LinkPlay-based devices).
class AmpSheet extends StatefulWidget {
  const AmpSheet({super.key, required this.controller, this.discovery});
  final RadioController controller;
  final ArylicDiscovery? discovery;

  @override
  State<AmpSheet> createState() => _AmpSheetState();
}

class _AmpSheetState extends State<AmpSheet> {
  late final _hostField = TextEditingController(
    text: widget.controller.ampHost ?? '',
  );
  List<DiscoveredAmp>? _found;
  bool _searching = false;
  bool _connecting = false;
  String? _error;

  RadioController get c => widget.controller;

  @override
  void dispose() {
    _hostField.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await (widget.discovery ?? ArylicDiscovery()).discover();
      if (!mounted) return;
      setState(() => _found = found);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _connect(String host) async {
    if (host.trim().isEmpty) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await c.connectAmp(host);
      _hostField.text = c.ampHost ?? host;
    } on Exception {
      if (mounted) {
        setState(
          () => _error =
              'No Arylic amp answered at $host. Check the IP and that the '
              'phone is on the same Wi-Fi.',
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final heading = TextStyle(fontSize: 12, color: colors.decorative);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ARYLIC AMP',
                style: TextStyle(fontSize: 18, color: colors.text),
              ),
              const SizedBox(height: 16),
              if (c.hasAmp) ...[
                Text(
                  '${c.ampName ?? 'Amp'} · ${c.ampHost}'
                  '${c.ampReachable ? '' : ' · unreachable'}',
                  style: TextStyle(
                    color: c.ampReachable ? colors.primary : colors.text,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Play radio on the amp'),
                  value: c.playsOnAmp,
                  onChanged: (on) =>
                      c.setOutput(on ? Output.amp : Output.phone),
                ),
                if (c.ampStatus != null) AmpVolumeSlider(controller: c),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: c.forgetAmp,
                    child: const Text('Forget this amp'),
                  ),
                ),
                const Divider(height: 32),
              ],
              Text('FIND ON THIS NETWORK', style: heading),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _searching ? null : _search,
                child: Text(_searching ? 'Searching…' : 'Search'),
              ),
              if (_found != null && _found!.isEmpty && !_searching)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No amps found. Enter the IP address below '
                    '(shown in the Arylic app under device info).',
                  ),
                ),
              for (final amp in _found ?? const <DiscoveredAmp>[])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(amp.name),
                  subtitle: Text(amp.host),
                  trailing: amp.host == c.ampHost
                      ? Icon(Icons.check, color: colors.primary)
                      : null,
                  onTap: _connecting ? null : () => _connect(amp.host),
                ),
              const SizedBox(height: 24),
              Text('OR ENTER ITS IP ADDRESS', style: heading),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostField,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: '192.168.1.50',
                      ),
                      onSubmitted: _connect,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _connecting
                        ? null
                        : () => _connect(_hostField.text),
                    child: Text(_connecting ? '…' : 'Connect'),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amp volume; sends the new value when the finger lifts so the amp is not
/// flooded with requests while dragging.
class AmpVolumeSlider extends StatefulWidget {
  const AmpVolumeSlider({super.key, required this.controller});
  final RadioController controller;

  @override
  State<AmpVolumeSlider> createState() => _AmpVolumeSliderState();
}

class _AmpVolumeSliderState extends State<AmpVolumeSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final status = widget.controller.ampStatus;
    final volume = _dragging ?? (status?.volume ?? 0).toDouble();
    final muted = status?.muted ?? false;
    return Row(
      children: [
        IconButton(
          tooltip: muted ? 'Unmute amp' : 'Mute amp',
          icon: Icon(
            muted ? Icons.volume_off : Icons.volume_up,
            color: colors.text,
            size: 20,
          ),
          onPressed: () => widget.controller.setAmpMuted(!muted),
        ),
        Expanded(
          child: Slider(
            value: volume,
            max: 100,
            label: volume.round().toString(),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) async {
              await widget.controller.setAmpVolume(v.round());
              if (mounted) setState(() => _dragging = null);
            },
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${volume.round()}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: colors.text),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
