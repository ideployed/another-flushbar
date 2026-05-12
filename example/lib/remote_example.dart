// An end-to-end example showing how to integrate FlushbarRemote into a Flutter
// app.  Replace 'YOUR_FLUSHKIT_API_KEY' with a real key from api.flushkit.dev.
//
// Run with: flutter run -t example/remote_example.dart

import 'package:another_flushbar/another_flushbar.dart';
import 'package:flutter/material.dart';

void main() => runApp(const RemoteExampleApp());

class RemoteExampleApp extends StatelessWidget {
  const RemoteExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'FlushbarRemote Example',
      home: RemoteHomePage(),
    );
  }
}

class RemoteHomePage extends StatefulWidget {
  const RemoteHomePage({super.key});

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  FlushbarRemoteEvent? _lastEvent;

  @override
  void initState() {
    super.initState();

    // Wait for the first frame so the Navigator is ready to push the Flushbar
    // route before we start receiving events.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlushbarRemote.init(
        apiKey: 'fk_live_afe62c2ac7c392252878257fd556b3282ac12dc9cf9f716a28afb937eb892983',
        context: context,
      );

      // Subscribe to raw events if you need custom handling in addition to
      // (or instead of) the automatic Flushbar display.
      FlushbarRemote.events.listen((event) {
        setState(() => _lastEvent = event);
      });
    });
  }

  @override
  void dispose() {
    // Always call dispose() so the SSE connection and timers are cleaned up.
    FlushbarRemote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FlushbarRemote Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Waiting for remote notifications from FlushKit…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_lastEvent != null) ...[
              const Text(
                'Last event (via FlushbarRemote.events stream):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                color: _lastEvent!.backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_lastEvent!.title != null)
                        Text(
                          _lastEvent!.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      Text(
                        _lastEvent!.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Position: ${_lastEvent!.position.name}  '
                        'Duration: ${_lastEvent!.duration.inSeconds}s',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
