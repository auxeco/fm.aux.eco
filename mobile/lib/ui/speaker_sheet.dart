import 'package:flutter/material.dart';

import '../arylic/arylic_discovery.dart';
import '../cast/cast_discovery.dart';
import '../controller/radio_controller.dart';
import 'theme.dart';

Future<void> showSpeakerSheet(
  BuildContext context,
  RadioController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => SpeakerSheet(controller: controller),
);

/// Choose where the radio plays: this phone, the Arylic amp or a Google
/// Cast speaker. Also sets up the Arylic amp.
class SpeakerSheet extends StatelessWidget {
  const SpeakerSheet({super.key, required this.controller, this.discovery});
  final RadioController controller;
  final ArylicDiscovery? discovery;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final c = controller;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          void choose(Future<void> Function() select) {
            Navigator.of(context).pop();
            select();
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PLAY ON',
                  style: TextStyle(fontSize: 18, color: colors.text),
                ),
                const SizedBox(height: 8),
                _SpeakerTile(
                  icon: Icons.smartphone,
                  title: 'This phone',
                  selected: !c.isRemote,
                  onTap: () => choose(c.selectPhone),
                ),
                if (c.hasAmp)
                  _SpeakerTile(
                    icon: Icons.speaker,
                    title: c.ampName ?? 'Amp',
                    subtitle:
                        'Arylic · ${c.ampHost}'
                        '${c.ampSelected && !c.remoteReachable ? ' · unreachable' : ''}',
                    selected: c.ampSelected,
                    onTap: () => choose(c.selectAmp),
                  ),
                for (final CastDevice d in c.castDevices)
                  _SpeakerTile(
                    icon: Icons.cast,
                    title: d.name,
                    subtitle: ['Google Cast', ?d.model].join(' · '),
                    selected: c.isCastSelected(d),
                    onTap: () => choose(() => c.selectCast(d)),
                  ),
                if (c.castDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Google Nest speakers and Chromecasts on this Wi-Fi '
                      'appear here.',
                      style: TextStyle(fontSize: 12, color: colors.decorative),
                    ),
                  ),
                if (c.isRemote && c.remoteStatus != null)
                  RemoteVolumeSlider(controller: c),
                const Divider(height: 32),
                _ArylicSetup(controller: c, discovery: discovery),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SpeakerTile extends StatelessWidget {
  const _SpeakerTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final color = selected ? colors.primary : colors.text;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: colors.decorative),
            ),
      trailing: selected ? Icon(Icons.check, color: colors.primary) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Find, connect or forget the Arylic amp (Up2Stream Amp and other
/// LinkPlay-based devices).
class _ArylicSetup extends StatefulWidget {
  const _ArylicSetup({required this.controller, this.discovery});
  final RadioController controller;
  final ArylicDiscovery? discovery;

  @override
  State<_ArylicSetup> createState() => _ArylicSetupState();
}

class _ArylicSetupState extends State<_ArylicSetup> {
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
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: !c.hasAmp,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        iconColor: colors.text,
        collapsedIconColor: colors.text,
        title: Text(
          c.hasAmp ? 'ARYLIC AMP SETTINGS' : 'CONNECT AN ARYLIC AMP',
          style: heading,
        ),
        children: [
          OutlinedButton(
            onPressed: _searching ? null : _search,
            child: Text(_searching ? 'Searching…' : 'Search this network'),
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
          const SizedBox(height: 16),
          Text('OR ENTER ITS IP ADDRESS', style: heading),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostField,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: '192.168.1.50'),
                  onSubmitted: _connect,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _connecting ? null : () => _connect(_hostField.text),
                child: Text(_connecting ? '…' : 'Connect'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (c.hasAmp)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: c.forgetAmp,
                child: const Text('Forget this amp'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Volume of the selected network speaker; sends the new value when the
/// finger lifts so the speaker is not flooded with requests while dragging.
class RemoteVolumeSlider extends StatefulWidget {
  const RemoteVolumeSlider({super.key, required this.controller});
  final RadioController controller;

  @override
  State<RemoteVolumeSlider> createState() => _RemoteVolumeSliderState();
}

class _RemoteVolumeSliderState extends State<RemoteVolumeSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final status = widget.controller.remoteStatus;
    final volume = _dragging ?? (status?.volume ?? 0).toDouble();
    final muted = status?.muted ?? false;
    return Row(
      children: [
        IconButton(
          tooltip: muted ? 'Unmute' : 'Mute',
          icon: Icon(
            muted ? Icons.volume_off : Icons.volume_up,
            color: colors.text,
            size: 20,
          ),
          onPressed: () => widget.controller.setRemoteMuted(!muted),
        ),
        Expanded(
          child: Slider(
            value: volume,
            max: 100,
            label: volume.round().toString(),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) async {
              await widget.controller.setRemoteVolume(v.round());
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
