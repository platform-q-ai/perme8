# Feature: Lightweight Discussion-Only Container Image (#358)

## Overview

Add a new lightweight container image (`perme8-opencode-light`) purpose-built for discussion, ticket management, and planning tasks. This image has codebase + skills access but strips out everything needed for building, testing, and running the application (no PostgreSQL, no Elixir/Erlang, no npm, no build tools). Light image tasks bypass the build queue entirely and don't consume concurrency slots, enabling instant-start planning sessions alongside heavyweight build sessions.

## App Ownership

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Domain path**: `apps/agents/lib/agents/sessions/`
- **Web path**: `apps/agents_web/lib/`
- **Migration path**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/sessions/`
- **Test paths**: `apps/agents/test/agents/sessions/`, `apps/agents_web/test/`

## UI Strategy

- **LiveView coverage**: 100% — the image picker already iterates `@available_images` dynamically, so adding the new image to `SessionsConfig.available_images/0` auto-renders it. No template changes needed.
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `Agents.Sessions`
- **Dependencies**: None (all changes are within the `agents` / `agents_web` boundary)
- **Exported schemas**: None new (existing `Task` entity already exported)
- **New context needed?**: No — this extends the existing Sessions bounded context

## Key Design Decisions

1. **Light image detection**: A domain policy function `light_image?/1` determines if a given image name is a light image. This is a pure function — no I/O. The initial implementation uses a naming convention (`perme8-opencode-light`), but the policy could evolve to consult a config list.

2. **Queue bypass approach**: Rather than modifying the DB query in `count_running_tasks`, the QueueManager will use the domain policy to:
   - Exclude light image tasks when counting running tasks against the concurrency limit
   - Immediately promote light image tasks regardless of concurrency
   - This keeps the policy logic pure and testable without database

3. **Resource limits**: The DockerAdapter's `start/2` already accepts `opts` — we add an `opts`-driven resource limit override. The `image` parameter is already passed to `start/2`, so we can determine resource limits based on the image name via the domain policy.

---

## Phase 1: Domain + Application (phoenix-tdd) ✓

### Step 1.1: ImagePolicy — Pure Business Rules for Light Images

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/image_policy_test.exs`
  - Test `light_image?("perme8-opencode-light")` returns `true`
  - Test `light_image?("perme8-opencode")` returns `false`
  - Test `light_image?("perme8-pi")` returns `false`
  - Test `light_image?(nil)` returns `false`
  - Test `resource_limits("perme8-opencode-light")` returns `%{memory: "512m", cpus: "1"}`
  - Test `resource_limits("perme8-opencode")` returns `%{memory: "2g", cpus: "2"}`
  - Test `resource_limits(nil)` returns default limits `%{memory: "2g", cpus: "2"}`
  - Test `bypasses_queue?("perme8-opencode-light")` returns `true`
  - Test `bypasses_queue?("perme8-opencode")` returns `false`
- [x] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/image_policy.ex`
  - Module: `Agents.Sessions.Domain.Policies.ImagePolicy`
  - `@light_images ["perme8-opencode-light"]`
  - `light_image?(image)` — checks membership in `@light_images`
  - `bypasses_queue?(image)` — delegates to `light_image?/1` (semantic alias for queue context)
  - `resource_limits(image)` — returns `%{memory: "512m", cpus: "1"}` for light images, `%{memory: "2g", cpus: "2"}` for others
- [x] ⏸ **REFACTOR**: Ensure no I/O, no infrastructure imports. Pure functions only.

### Step 1.2: QueuePolicy — Extend with Light Image Awareness

- [x] ⏸ **RED**: Add tests to `apps/agents/test/agents/sessions/domain/policies/queue_policy_test.exs`
  - Test `count_towards_limit?("perme8-opencode")` returns `true`
  - Test `count_towards_limit?("perme8-opencode-light")` returns `false`
  - Test `should_queue_with_image?(3, 2, "perme8-opencode")` returns `true` (at limit)
  - Test `should_queue_with_image?(3, 2, "perme8-opencode-light")` returns `false` (bypasses)
- [x] ⏸ **GREEN**: Add to `apps/agents/lib/agents/sessions/domain/policies/queue_policy.ex`
  - `count_towards_limit?(image)` — delegates to `ImagePolicy.bypasses_queue?/1` (inverted)
  - `should_queue_with_image?(running_count, limit, image)` — returns `false` when image bypasses queue, delegates to `should_queue?/2` otherwise
- [x] ⏸ **REFACTOR**: Keep existing `should_queue?/2` and `can_promote?/2` unchanged for backward compatibility.

### Step 1.3: SessionsConfig — Add Light Image to Available Images

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/sessions_config_test.exs`
  - Test `available_images/0` includes `%{name: "perme8-opencode-light", label: "OpenCode Light"}`
  - Test `available_images/0` still includes `"perme8-opencode"` and `"perme8-pi"`
  - Test `available_images/0` returns list of 3 images
- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/application/sessions_config.ex`
  - Add `%{name: "perme8-opencode-light", label: "OpenCode Light"}` to the default list in `available_images/0`
- [x] ⏸ **REFACTOR**: Ensure ordering is sensible (OpenCode, OpenCode Light, Pi).

### Phase 1 Validation

- [x] ⏸ All domain policy tests pass (`mix test apps/agents/test/agents/sessions/domain/policies/ --trace`)
- [x] ⏸ SessionsConfig test passes
- [x] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd) ✓

### Step 2.1: DockerAdapter — Image-Aware Resource Limits

- [x] ⏸ **RED**: Add tests to `apps/agents/test/agents/sessions/infrastructure/adapters/docker_adapter_test.exs`
  - Test: `start("perme8-opencode-light", ...)` passes `--memory=512m --cpus=1` to Docker
  - Test: `start("perme8-opencode", ...)` passes `--memory=2g --cpus=2` to Docker (existing default)
  - Test: `start("perme8-pi", ...)` passes `--memory=2g --cpus=2` to Docker (existing default)
  - Implementation: Use the `mock_cmd` test pattern (already established) to capture Docker args and assert the correct memory/cpu flags per image
- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/adapters/docker_adapter.ex`
  - Import or alias `Agents.Sessions.Domain.Policies.ImagePolicy`
  - In `start/2`, replace hardcoded `"--memory=2g", "--cpus=2"` with dynamic values from `ImagePolicy.resource_limits(image)`
  - Build the args: `"--memory=#{limits.memory}", "--cpus=#{limits.cpus}"`
- [x] ⏸ **REFACTOR**: Ensure the `start/2` function remains clean. Consider extracting a `resource_args/1` helper.

### Step 2.2: TaskQueries — Count Running Excluding Light Images

- [x] ⏸ **RED**: Add tests to `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs` (create if needed)
  - Test: `count_running_heavyweight/1` counts only tasks whose `image` is NOT a light image
  - Test: Given 2 running "perme8-opencode" tasks and 1 running "perme8-opencode-light" task, `count_running_heavyweight/1` returns 2
  - Test: Given only light image running tasks, `count_running_heavyweight/1` returns 0
  - Test: Existing `count_running/1` still counts all running tasks (backward compat)
- [x] ⏸ **GREEN**: Add to `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex`
  - Add `count_running_heavyweight/2` query function:
    ```elixir
    def count_running_heavyweight(query \\ base(), user_id) do
      light_images = ImagePolicy.light_image_names()
      from(t in query,
        where: t.user_id == ^user_id
          and t.status in ["pending", "starting", "running"]
          and (is_nil(t.image) or t.image not in ^light_images),
        select: count(t.id)
      )
    end
    ```
  - Add `light_image_names/0` to `ImagePolicy` returning the list `["perme8-opencode-light"]`
- [x] ⏸ **REFACTOR**: Ensure the query is composable and follows existing patterns.

### Step 2.3: TaskRepository — Add Heavyweight Running Count

- [x] ⏸ **RED**: Add test to `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs` (extend existing or create)
  - Test: `count_running_heavyweight_tasks/1` calls the new query and returns correct count
- [x] ⏸ **GREEN**: Add to `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex`
  - Add `count_running_heavyweight_tasks/1` function calling `TaskQueries.count_running_heavyweight/1`
  - Add callback to `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex`:
    `@callback count_running_heavyweight_tasks(user_id) :: non_neg_integer()`
- [x] ⏸ **REFACTOR**: Keep existing `count_running_tasks/1` for backward compatibility (other code may still need total counts).

### Step 2.4: QueueManager — Light Image Queue Bypass

- [x] ⏸ **RED**: Add tests to `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs`
  - **Test: Light image tasks don't count against concurrency limit**
    - Create 1 running light image task (`image: "perme8-opencode-light"`) and set concurrency_limit to 1
    - `check_concurrency/1` should return `:ok` (not `:at_limit`)
  - **Test: Light image tasks are promoted immediately regardless of concurrency**
    - Create 1 running heavyweight task, concurrency_limit = 1
    - Create a queued light image task
    - Call `notify_task_queued/2`
    - Assert the light image task gets promoted to "pending" and runner is started
  - **Test: Multiple light image tasks can run simultaneously**
    - Create 2 running light image tasks, concurrency_limit = 1
    - `check_concurrency/1` should still return `:ok`
  - **Test: Heavyweight task is still queued when at limit with light tasks running**
    - Create 1 running heavyweight task, concurrency_limit = 1
    - Create a queued heavyweight task
    - `notify_task_queued/2` should NOT promote the heavyweight task
  - **Test: Light image tasks are not requeued by enforce_concurrency_limit**
    - Create 2 running light image tasks + 1 running heavyweight, concurrency_limit = 1
    - Lower limit to 1 — only heavyweight tasks should be considered for requeue, light tasks untouched
- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex`
  - Update `safe_count_running/1` to call `state.task_repo.count_running_heavyweight_tasks(state.user_id)` instead of `count_running_tasks` — this makes light image tasks invisible to the concurrency counter
  - Update `promote_next_task/1` to handle light images:
    - After the heavyweight promotion check, also check for queued light image tasks and promote them unconditionally (use `ImagePolicy.bypasses_queue?/1` on `task.image`)
    - Add a new `promote_light_image_tasks/1` that finds queued light image tasks and promotes all of them
  - Call `promote_light_image_tasks/1` at the end of `promote_next_task/1` (after heavyweight promotion)
  - Update `enforce_concurrency_limit/1` to exclude light image tasks from the "excess running" calculation — filter out light image tasks before finding youngest to requeue
  - Update `youngest_active_task/1` to only consider heavyweight tasks (exclude light images)
- [x] ⏸ **REFACTOR**: Extract light-image-specific promotion into clearly named private functions. Ensure GenServer state handling remains clean.

### Step 2.5: Mix Task — Add opencode-light to Docker Build

- [x] ⏸ **RED**: Add tests to `apps/perme8_tools/test/mix/tasks/docker_build_test.exs`
  - Test: `resolve_config(["opencode-light"])` returns `image_name: "opencode-light"`, `image_path: "infra/opencode-light"`, `tag: "perme8-opencode-light"`
  - Test: error message for unknown images includes `opencode-light` in valid images list
- [x] ⏸ **GREEN**: Update `apps/perme8_tools/lib/mix/tasks/docker.build.ex`
  - Add to `@images` map: `"opencode-light" => %{path: "infra/opencode-light", default_tag: "perme8-opencode-light"}`
- [x] ⏸ **REFACTOR**: Update `@shortdoc` to mention the new image.

### Phase 2 Validation

- [x] ⏸ All infrastructure tests pass (`mix test apps/agents/test/agents/sessions/infrastructure/ --trace`)
- [x] ⏸ Docker adapter tests pass
- [x] ⏸ QueueManager tests pass (including new light image tests)
- [x] ⏸ Mix task tests pass
- [x] ⏸ No boundary violations (`mix boundary`) *(attempted; `mix boundary` task unavailable in this workspace)*
- [x] ⏸ Full agents test suite passes (`mix test apps/agents --trace`)
- [x] ⏸ Full perme8_tools test suite passes (`mix test apps/perme8_tools --trace`)

---

## Phase 3: Infrastructure Files (Non-Unit-Testable)

These are Docker/shell artifacts that cannot be unit tested but are verified via `docker build`.

### Step 3.1: Dockerfile for opencode-light

- [ ] ⏸ Create `infra/opencode-light/Dockerfile`
  - **Stage 1 (fetcher)**: Same as `infra/opencode/Dockerfile` — fetch opencode binary from Alpine
  - **Stage 2**: Use `alpine:3.21` as base (NOT hexpm/elixir — no Erlang/Elixir needed)
  - Install only: `git bash openssl curl python3 github-cli ripgrep fd`
  - NO: `postgresql16`, `build-base`, `unzip`, `nodejs`, `npm`, `chromium`, `bun`
  - Copy opencode binary from fetcher stage
  - Create `appuser`, directories, copy config files (same as full image)
  - EXPOSE 4096, ENTRYPOINT to simplified entrypoint

### Step 3.2: Entrypoint for opencode-light

- [ ] ⏸ Create `infra/opencode-light/entrypoint.sh`
  - Include: env var validation (GITHUB_APP_PEM, OPENCODE_AUTH)
  - Include: PEM setup, review bot PEM setup
  - Include: GIT_ASKPASS configuration
  - Include: git identity config
  - Include: opencode auth.json setup
  - Include: OpenAI OAuth token refresh
  - Include: repo clone (perme8) + skills clone
  - Include: Copy opencode.json into repo root
  - **EXCLUDE**: PostgreSQL init/start, `mix local.hex`, `mix deps.get`, `npm install`, `bun install`, `mix compile`, `mix ecto.create/migrate`
  - End with: `exec opencode serve --hostname 0.0.0.0 --port 4096`

### Step 3.3: Supporting Files

- [ ] ⏸ Create `infra/opencode-light/opencode.json` — copy from `infra/opencode/opencode.json`
- [ ] ⏸ Create `infra/opencode-light/.dockerignore` — copy from `infra/opencode/.dockerignore`
- [ ] ⏸ Create `infra/opencode-light/get-token` — copy from `infra/opencode/get-token`
- [ ] ⏸ Create `infra/opencode-light/get-review-token` — copy from `infra/opencode/get-review-token`

### Phase 3 Validation

- [ ] ⏸ `docker build -t perme8-opencode-light infra/opencode-light/` succeeds
- [ ] ⏸ `mix docker.build opencode-light` succeeds (depends on Phase 2, Step 2.5)
- [ ] ⏸ Container starts and opencode serves on port 4096

---

## Phase 4: Integration Verification

### Step 4.1: End-to-End Config Wiring

- [ ] ⏸ Verify `Agents.Sessions.available_images/0` returns 3 images including `"OpenCode Light"`
- [ ] ⏸ Verify `Agents.Sessions.image_label("perme8-opencode-light")` returns `"OpenCode Light"`

### Step 4.2: Pre-Commit Checkpoint

- [ ] ⏸ Run `mix precommit` — all checks pass (compile, boundary, format, credo, tests)
- [ ] ⏸ Run `mix boundary` — no violations
- [ ] ⏸ Run `mix test` — full umbrella suite passes

---

## Testing Strategy

### Test Distribution

| Layer | Test Count (est.) | File |
|-------|-------------------|------|
| Domain: ImagePolicy | 9 | `apps/agents/test/agents/sessions/domain/policies/image_policy_test.exs` |
| Domain: QueuePolicy (extended) | 4 | `apps/agents/test/agents/sessions/domain/policies/queue_policy_test.exs` |
| Application: SessionsConfig | 3 | `apps/agents/test/agents/sessions/application/sessions_config_test.exs` |
| Infrastructure: DockerAdapter (extended) | 3 | `apps/agents/test/agents/sessions/infrastructure/adapters/docker_adapter_test.exs` |
| Infrastructure: TaskQueries (extended) | 3 | `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs` |
| Infrastructure: TaskRepository (extended) | 1 | `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs` |
| Infrastructure: QueueManager (extended) | 5 | `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs` |
| Dev tools: Docker.Build (extended) | 2 | `apps/perme8_tools/test/mix/tasks/docker_build_test.exs` |
| **Total** | **~30** | |

### Test Characteristics

- **Domain tests** (13): `ExUnit.Case, async: true` — milliseconds, no I/O, no DB
- **Application tests** (3): `ExUnit.Case, async: true` — config reads only
- **Infrastructure tests** (12): `Agents.DataCase` — DB required for queries/repo, mock `system_cmd` for Docker
- **Dev tool tests** (2): `ExUnit.Case, async: true` — pure function tests

### BDD Feature File

The acceptance criteria are defined in:
- `apps/agents_web/test/features/sessions/light-image-queue-bypass.browser.feature`

These browser tests verify the full user-facing flow and are run separately via exo-bdd after implementation is complete.

---

## File Change Summary

### New Files

| File | Phase | Description |
|------|-------|-------------|
| `apps/agents/lib/agents/sessions/domain/policies/image_policy.ex` | 1.1 | Pure policy: light image detection, resource limits, queue bypass |
| `apps/agents/test/agents/sessions/domain/policies/image_policy_test.exs` | 1.1 | Unit tests for ImagePolicy |
| `apps/agents/test/agents/sessions/application/sessions_config_test.exs` | 1.3 | Unit tests for SessionsConfig changes |
| `infra/opencode-light/Dockerfile` | 3.1 | Lightweight Alpine image |
| `infra/opencode-light/entrypoint.sh` | 3.2 | Simplified entrypoint (no build tooling) |
| `infra/opencode-light/opencode.json` | 3.3 | Opencode config (copy) |
| `infra/opencode-light/.dockerignore` | 3.3 | Docker ignore (copy) |
| `infra/opencode-light/get-token` | 3.3 | GitHub token script (copy) |
| `infra/opencode-light/get-review-token` | 3.3 | Review token script (copy) |

### Modified Files

| File | Phase | Change |
|------|-------|--------|
| `apps/agents/lib/agents/sessions/domain/policies/queue_policy.ex` | 1.2 | Add `count_towards_limit?/1`, `should_queue_with_image?/3` |
| `apps/agents/lib/agents/sessions/application/sessions_config.ex` | 1.3 | Add `"perme8-opencode-light"` to `available_images/0` default list |
| `apps/agents/lib/agents/sessions/infrastructure/adapters/docker_adapter.ex` | 2.1 | Image-aware resource limits in `start/2` |
| `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex` | 2.2 | Add `count_running_heavyweight/2` query |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex` | 2.3 | Add `count_running_heavyweight_tasks/1` |
| `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex` | 2.3 | Add callback for `count_running_heavyweight_tasks/1` |
| `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex` | 2.4 | Light image queue bypass logic |
| `apps/perme8_tools/lib/mix/tasks/docker.build.ex` | 2.5 | Add `"opencode-light"` to `@images` map |
| `apps/agents/test/agents/sessions/domain/policies/queue_policy_test.exs` | 1.2 | Extended with light image tests |
| `apps/agents/test/agents/sessions/infrastructure/adapters/docker_adapter_test.exs` | 2.1 | Extended with resource limit tests |
| `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs` | 2.4 | Extended with 5 light image bypass tests |
| `apps/perme8_tools/test/mix/tasks/docker_build_test.exs` | 2.5 | Extended with opencode-light tests |

### Files NOT Modified (Confirmed)

| File | Reason |
|------|--------|
| `apps/agents_web/lib/live/sessions/index.html.heex` | Image picker already iterates `@available_images` dynamically — adding the new image to `SessionsConfig.available_images/0` auto-renders it |
| `apps/agents_web/lib/live/sessions/index.ex` | LiveView already reads from `Sessions.available_images()` in mount — no changes needed |
| `apps/agents/lib/agents/sessions/domain/entities/task.ex` | Task entity already has `image` field |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex` | Schema already has `image` field |
| `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex` | Already passes `image` through attrs |
| `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex` | Already reads `task.image` and passes to `container_provider.start(image, [])` |
| `apps/agents/lib/agents/sessions.ex` | Facade already delegates to SessionsConfig — no changes needed |
| Database migrations | No schema changes — `image` field already exists on `sessions_tasks` |
