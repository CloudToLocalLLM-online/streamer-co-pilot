// Streamer Co-Pilot Agent Library
//
// Reference implementation of the agent decision loop:
// poll `/state`, decide, send `/command`.
//
// This library provides:
// - [AgentClient] — HTTP + SSE client for the AgentServer API
// - [DecisionLoop] — Configurable poll/decide/act loop
// - Built-in [DecisionRule]s for common streaming automation
export 'agent_client.dart';
export 'decision_loop.dart';