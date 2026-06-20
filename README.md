# Game Template (Godot 4)

Ready-to-clone project skeleton with **gd-common** pre-wired as a submodule.
New game = clone this, rename, build.

## Structure

```
addons/gd-common/   reusable generic layer (submodule: EventBus/SaveSystem/AudioManager/UIManager/FSM/utils/Gauge)
core/
  game_data.gd      [autoload GameData]    your model + persistence (uses SaveSystem)
  game_manager.gd   [autoload GameManager] your flow controller (uses GxStateMachine)
  data/             CSV / data tables
scenes/
  main.tscn         entry scene
  levels/ actors/ ui/ fx/
assets/             art / audio / fonts
```

## First-time setup

```
git clone <this> my-game
cd my-game
git submodule update --init --recursive
```

Open in Godot, enable the **gd-common** plugin (Project Settings → Plugins) if not
already enabled, then run.

## Conventions

- gd-common provides genre-agnostic infra (autoloads `EventBus`/`SaveSystem`/`AudioManager`/`UIManager`, classes `Gx*`).
- Keep game-specific code in `core/` and `scenes/`; never push it into the submodule.
- Follow the decoupling rules in `addons/gd-common/README.md`.

## Update the shared library

```
git -C addons/gd-common pull origin main
git add addons/gd-common && git commit -m "bump gd-common"
```
