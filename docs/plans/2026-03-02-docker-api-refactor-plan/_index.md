# PhoneDriver Docker + API Refactor - Implementation Plan

## Goal

Refactor PhoneDriver to replace local GPU inference with OpenAI-compatible API calls and package the control logic in a lightweight Docker container for macOS deployment.

## Design Reference

- Design: `docs/plans/2026-03-02-docker-api-refactor-design/`
- BDD Specs: `specs/*.feature` (89 scenarios across 4 files)

## Architecture Summary

```
[GPU Server: vLLM/Ollama] <--API-- [macOS Docker: PhoneDriver] --ADB--> [Host ADB Server] --USB--> [Phone]
```

## Constraints

- API-only mode: remove all local inference code (torch, transformers)
- OpenAI-compatible API via `openai` Python SDK
- ADB via host server forwarding (`ADB_SERVER_SOCKET`)
- Docker image < 500MB
- Preserve all existing ADB control logic and Gradio UI structure

## Dependency Graph

```
task-001 (infrastructure) ──────────────────────> task-005 (Dockerfile) ──> task-006 (compose)
                                                                                    │
task-002 (VL agent rewrite) ──> task-003 (config + phone_agent) ──> task-004 (UI) ──┤
                                                                                    │
                                                                                    v
                                                                          task-007 (verify)
```

Tasks 001 and 002 are independent and can be executed in parallel.
Tasks 005 depends only on 001 and can run in parallel with 002/003/004.

## Execution Plan

- [Task 001: Create project infrastructure files](./task-001-infrastructure-files.md)
- [Task 002: Rewrite qwen_vl_agent.py as OpenAI API client](./task-002-rewrite-vl-agent.md)
- [Task 003: Update config schema and phone_agent.py integration](./task-003-config-and-phone-agent.md)
- [Task 004: Update ui.py settings for API configuration](./task-004-update-ui-settings.md)
- [Task 005: Create Dockerfile](./task-005-create-dockerfile.md)
- [Task 006: Create docker-compose.yml](./task-006-create-docker-compose.md)
- [Task 007: End-to-end integration verification](./task-007-integration-verification.md)

## Commit Strategy

- Commit after task-001 + task-002 (foundation + core refactoring)
- Commit after task-003 + task-004 (config + UI updates)
- Commit after task-005 + task-006 (Docker setup)
- Final commit after task-007 (verification fixes if any)
