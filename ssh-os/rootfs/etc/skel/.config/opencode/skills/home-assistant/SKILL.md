---
name: home-assistant
description: Guide for editing Home Assistant YAML configuration files, automations, scripts, sensors, dashboards, and packages
compatibility: opencode
---

## Home Assistant Configuration

You are working inside a Home Assistant environment. The configuration directory is mounted at `/homeassistant`.

### File Layout

```
/homeassistant/
  configuration.yaml    # Main config, loads other files via includes
  automations.yaml      # UI-created automations (list format)
  scripts.yaml          # UI-created scripts (list format)
  scenes.yaml           # UI-created scenes (list format)
  secrets.yaml          # Secret values (passwords, tokens, API keys)
  customize.yaml        # Entity customizations
  packages/             # Package-based config (self-contained bundles)
  blueprints/           # Automation and script blueprints
  custom_components/    # HACS and manual custom integrations
  www/                  # Static files served at /local/
  dashboards/           # Lovelace dashboard YAML files
```

### Key Rules

- **Never expose secrets.** Use `!secret key_name` references instead of hardcoding values. Secrets are defined in `secrets.yaml`.
- **Validate before restarting.** Always run `ha core check` after config changes. Only suggest a restart if validation passes.
- **Preserve UI-managed files.** Files like `automations.yaml`, `scripts.yaml`, and `scenes.yaml` use a list format managed by the UI. Edits must preserve this format (list of objects with `id`, `alias`, etc.).
- **Use packages for organization.** Packages under `packages/` bundle related entities together. Each package is a self-contained YAML file that mirrors the top-level config structure.

### YAML Syntax

Home Assistant extends YAML with special constructors:

| Syntax | Purpose |
|--------|---------|
| `!include file.yaml` | Include a single file |
| `!include_dir_named dir/` | Include directory as named mapping |
| `!include_dir_list dir/` | Include directory as list |
| `!include_dir_merge_named dir/` | Merge directory files into one mapping |
| `!include_dir_merge_list dir/` | Merge directory files into one list |
| `!secret key` | Reference a value from secrets.yaml |
| `!env_var VAR` | Reference an environment variable |

### Jinja2 Templates

Templates use Jinja2 syntax inside YAML values:

```yaml
sensor:
  - platform: template
    sensors:
      friendly_temp:
        value_template: "{{ states('sensor.temperature') | float | round(1) }}"
        unit_of_measurement: "F"
```

Common template objects: `states('entity_id')`, `state_attr('entity_id', 'attribute')`, `is_state('entity_id', 'value')`, `now()`, `as_timestamp()`.

### Automations

Manual automations in `configuration.yaml` or packages use the mapping format:

```yaml
automation:
  - alias: "Turn on lights at sunset"
    trigger:
      - platform: sun
        event: sunset
        offset: "-00:30:00"
    condition:
      - condition: state
        entity_id: binary_sensor.someone_home
        state: "on"
    action:
      - service: light.turn_on
        target:
          entity_id: light.living_room
```

### Available CLI

The `ha` command provides access to the Home Assistant CLI:

| Command | Purpose |
|---------|---------|
| `ha core check` | Validate configuration |
| `ha core restart` | Restart Home Assistant |
| `ha core stats` | Show resource usage |
| `ha core info` | Show version and status |
| `ha addons list` | List installed add-ons |
| `ha host info` | Show host system info |
