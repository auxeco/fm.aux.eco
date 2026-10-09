import 'package:flutter/material.dart';

import '../audio/stream_probe.dart';
import '../controller/radio_controller.dart';
import '../controller/station_library.dart';
import '../models/station.dart';
import 'theme.dart';

typedef StreamChecker = Future<StreamProbe> Function(String url);

/// Choose which stations are in the list, and add your own.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.checkStream = probeStream,
  });

  final RadioController controller;
  final StreamChecker checkStream;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    final border = BorderSide(color: colors.decorative);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(border: Border(bottom: border)),
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back, color: colors.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 4,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final library = controller.library;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      const _Heading('STATIONS'),
                      _Hint('Tick the stations you want in your list.'),
                      const SizedBox(height: 8),
                      _Group(
                        title: 'AUX FM SELECTION',
                        stations: library.selection,
                        controller: controller,
                      ),
                      if (library.more.isNotEmpty)
                        _Group(
                          title: 'MORE STATIONS',
                          stations: library.more,
                          controller: controller,
                        ),
                      _Group(
                        title: 'YOUR STATIONS',
                        stations: library.custom,
                        controller: controller,
                        deletable: true,
                        empty: 'Stations you add below appear here.',
                      ),
                      const Divider(height: 40),
                      const _Heading('ADD A STATION'),
                      _AddStation(
                        controller: controller,
                        checkStream: checkStream,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 16,
        letterSpacing: 2,
        color: AuxColors.of(context).text,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, color: AuxColors.of(context).decorative),
  );
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.stations,
    required this.controller,
    this.deletable = false,
    this.empty,
  });

  final String title;
  final List<Station> stations;
  final RadioController controller;
  final bool deletable;
  final String? empty;

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            title,
            style: TextStyle(fontSize: 11, color: colors.decorative),
          ),
        ),
        if (stations.isEmpty && empty != null) _Hint(empty!),
        for (final s in stations)
          _StationTile(
            station: s,
            enabled: controller.library.isEnabled(s),
            onChanged: (on) {
              if (!controller.setStationEnabled(s, on)) {
                _snack(context, 'Keep at least one station in your list.');
              }
            },
            onDelete: deletable
                ? () async {
                    if (!await controller.removeStation(s)) {
                      if (context.mounted) {
                        _snack(
                          context,
                          'Keep at least one station in your list.',
                        );
                      }
                    }
                  }
                : null,
          ),
      ],
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.enabled,
    required this.onChanged,
    this.onDelete,
  });

  final Station station;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Checkbox(
        value: enabled,
        activeColor: colors.primary,
        checkColor: colors.background,
        side: BorderSide(color: colors.decorative, width: 1.5),
        onChanged: (v) => onChanged(v ?? false),
      ),
      title: Text(
        station.name,
        style: TextStyle(fontSize: 15, color: colors.text),
      ),
      subtitle: Text(
        station.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colors.decorative),
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: 'Delete ${station.name}',
              icon: Icon(Icons.delete_outline, color: colors.text, size: 20),
              onPressed: onDelete,
            ),
      onTap: () => onChanged(!enabled),
    );
  }
}

class _AddStation extends StatefulWidget {
  const _AddStation({required this.controller, required this.checkStream});
  final RadioController controller;
  final StreamChecker checkStream;

  @override
  State<_AddStation> createState() => _AddStationState();
}

class _AddStationState extends State<_AddStation> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final error = validateStation(name, url);
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _checking = true);
    final probe = await widget.checkStream(url);
    if (!mounted) return;
    setState(() => _checking = false);

    if (probe.kind == 'playlist') {
      setState(
        () => _error =
            'That is a playlist file (.pls / .m3u), not the stream itself. '
            'Open it in a browser and use the address inside.',
      );
      return;
    }
    widget.controller.addStation(name: name, url: url);
    _name.clear();
    _url.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            probe.ok
                ? 'Added $name to your list.'
                : 'Added $name, but it could not be confirmed as a stream. '
                      'If it does not play, check the address.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuxColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Stream URL',
            hintText: 'https://example.com/stream.mp3',
          ),
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: 8),
        _Hint(
          "The station's direct stream address (MP3, AAC or HLS), not its "
          'website. Stations often list it under "listen" or "player".',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _checking ? null : _add,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.background,
          ),
          child: Text(_checking ? 'Checking the stream…' : 'Add station'),
        ),
      ],
    );
  }
}
