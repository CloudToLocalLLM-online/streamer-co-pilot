// Standalone agent runner for Streamer Co-Pilot.
//
// Usage:
//   dart run lib/agent/agent_main.dart [--host localhost] [--port 8511] [--interval 5]
//
// This demonstrates the "poll `/state`, decide, send `/command`" decision loop
// from the roadmap. Can be used as a reference for Hermes/OpenClaw integration.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'agent_client.dart';
import 'decision_loop.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('host', abbr: 'h', defaultsTo: 'localhost', help: 'AgentServer host')
    ..addOption('port', abbr: 'p', defaultsTo: '8511', help: 'AgentServer port')
    ..addOption('interval', abbr: 'i', defaultsTo: '5', help: 'Poll interval (seconds)')
    ..addFlag('verbose', abbr: 'v', defaultsTo: false, help: 'Verbose logging')
    ..addFlag('help', abbr: '?', negatable: false, help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('Streamer Co-Pilot Agent — Decision Loop Reference Implementation');
    print('');
    print(parser.usage);
    return;
  }

  final host = results['host'] as String;
  final port = int.parse(results['port'] as String);
  final interval = int.parse(results['interval'] as String);
  final verbose = results['verbose'] as bool;

  final baseUrl = 'http://$host:$port';
  final client = AgentClient(baseUrl: baseUrl);
  final config = DecisionLoopConfig(
    pollInterval: Duration(seconds: interval),
    rules: defaultRules(),
    onLog: verbose ? (msg) => print(msg) : null,
    // Stop after 10 iterations in demo mode, or run forever
    shouldContinue: (state) => true,
  );

  final loop = DecisionLoop(client: client, config: config);

  // Handle shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await loop.stop();
    await client.close();
    exit(0);
  });
  ProcessSignal.sigterm.watch().listen((_) async {
    await loop.stop();
    await client.close();
    exit(0);
  });

  print('Starting agent: $baseUrl (poll every ${interval}s)');
  print('Press Ctrl+C to stop');
  print('');

  try {
    await loop.start();
    // Keep running until stopped
    while (loop.isRunning) {
      await Future.delayed(const Duration(seconds: 1));
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  } finally {
    await client.close();
  }
}