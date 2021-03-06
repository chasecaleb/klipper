This document provides information on implementing G-Code command
sequences in gcode_macro (and similar) config sections.

### Formatting of G-Code in the config

Indentation is important when defining a macro in the config file. To
specify a multi-line G-Code sequence it is important for each line to
have proper indentation. For example:

```
[gcode_macro blink_led]
gcode:
  SET_PIN PIN=my_led VALUE=1
  G4 P2000
  SET_PIN PIN=my_led VALUE=0
```

Note how the `gcode:` config option always starts at the beginning of
the line and subsequent lines in the G-Code macro never start at the
beginning.

### Save/Restore state for G-Code moves

Unfortunately, the G-Code command language can be challenging to use.
The standard mechanism to move the toolhead is via the `G1` command
(the `G0` command is an alias for `G1` and it can be used
interchangeably with it). However, this command relies on the "G-Code
parsing state" setup by `M82`, `M83`, `G90`, `G91`, `G92`, and
previous `G1` commands.  When creating a G-Code macro it is a good
idea to always explicitly set the G-Code parsing state prior to
issuing a `G1` command. (Otherwise, there is a risk the `G1` command
will make an undesirable request.)

A common way to accomplish that is to wrap the `G1` moves in
`SAVE_GCODE_STATE`, `G91`, and `RESTORE_GCODE_STATE`. For example:

```
[gcode_macro MOVE_UP]
gcode:
  SAVE_GCODE_STATE NAME=my_move_up_state
  G91
  G1 Z10 F300
  RESTORE_GCODE_STATE NAME=my_move_up_state
```

The `G91` command places the G-Code parsing state into "relative move
mode" and the `RESTORE_GCODE_STATE` command restores the state to what
it was prior to entering the macro. Be sure to specify an explicit
speed (via the `F` parameter) on the first `G1` command.

### Template expansion
<!-- {% raw %} -->

The gcode_macro `gcode:` config section is evaluated using the Jinja2
template language. One can evaluate expressions at run-time by
wrapping them in `{ }` characters or use conditional statements
wrapped in `{% %}`. See the
[Jinja2 documentation](http://jinja.pocoo.org/docs/2.10/templates/)
for further information on the syntax.

This is most often used to inspect parameters passed to the macro when
it is called. These parameters are available via the `params`
pseudo-variable. For example, if the macro:

```
[gcode_macro SET_PERCENT]
gcode:
  M117 Now at { params.VALUE|float * 100 }%
```

were invoked as `SET_PERCENT VALUE=.2` it would evaluate to `M117 Now
at 20%`. Note that parameter names are always in upper-case when
evaluated in the macro and are always passed as strings. If performing
math then they must be explicitly converted to integers or floats.

An example of a complex macro:
```
[gcode_macro clean_nozzle]
gcode:
  SAVE_GCODE_STATE NAME=clean_nozzle_state
  G90
  G0 Z15 F300
  {% for wipe in range(8) %}
    {% for coordinate in [(275,4),(235,4)] %}
      G0 X{coordinate[0]} Y{coordinate[1] + 0.25 * wipe} Z9.7 F12000
    {% endfor %}
  {% endfor %}
  RESTORE_GCODE_STATE NAME=clean_nozzle_state
```
<!-- {% endraw %} -->

#### The "printer" Variable

It is possible to inspect (and alter) the current state of the printer
via the `printer` pseudo-variable. For example:

```
[gcode_macro slow_fan]
gcode:
  M106 S{ printer.fan.speed * 0.9 * 255}
```

Important! Macros are first evaluated in entirety and only then are
the resulting commands executed. If a macro issues a command that
alters the state of the printer, the results of that state change will
not be visible during the evaluation of the macro. This can also
result in subtle behavior when a macro generates commands that call
other macros, as the called macro is evaluated when it is invoked
(which is after the entire evaluation of the calling macro).

By convention, the name immediately following `printer` is the name of
a config section. So, for example, `printer.fan` refers to the fan
object created by the `[fan]` config section. There are some
exceptions to this rule - notably the `gcode` and `toolhead` objects.
If the config section contains spaces in it, then one can access it
via the `[ ]` accessor - for example:
`printer["generic_heater my_chamber_heater"].temperature`.

Some printer objects allow one to alter the state of the printer. By
convention, these objects use an `action_` prefix. For example,
`printer.gcode.action_emergency_stop()` would cause the printer to go
into a shutdown state. These actions are taken at the time that the
macro is evaluated, which may be a significant amount of time before
the generated commands are executed.

The following are common printer attributes:
- `printer.fan.speed`: The fan speed as a float between 0.0 and 1.0.
- `printer.gcode.action_respond_info(msg)`: Write the given `msg` to
  the /tmp/printer pseudo-terminal. Each line of `msg` will be sent
  with a "// " prefix.
- `printer.gcode.action_respond_error(msg)`: Write the given `msg` to
  the /tmp/printer pseudo-terminal. The first line of `msg` will be
  sent with a "!! " prefix and subsequent lines will have a "// "
  prefix.
- `printer.gcode.action_emergency_stop(msg)`: Transition the printer
  to a shutdown state. The `msg` parameter is optional, it may be
  useful to describe the reason for the shutdown.
- `printer.gcode.gcode_position`: The current position of the toolhead
  relative to the current G-Code origin. It is possible to access the
  x, y, z, and e components of this position (eg,
  `printer.gcode.gcode_position.x`).
- `printer["gcode_macro <macro_name>"].<variable>`: The current value
  of a gcode_macro variable.
- `printer.<heater>.temperature`: The last reported temperature (in
  Celsius as a float) for the given heater. Available heaters are:
  `heater_bed` and `heater_generic <config_name>`.
- `printer.<heater>.target`: The current target temperature (in
  Celsius as a float) for the given heater.
- `printer.pause_resume.is_paused`: Returns true if a PAUSE command
  has been executed without a corresponding RESUME.
- `printer.toolhead.position`: The last commanded position of the
  toolhead relative to the coordinate system specified in the config
  file. It is possible to access the x, y, z, and e components of this
  position (eg, `printer.toolhead.position.x`).

The above list is subject to change - if using an attribute be sure to
review the [Config Changes document](Config_Changes.md) when upgrading
the Klipper software. The above list is not exhaustive.  Other
attributes may be available (via `get_status()` methods defined in the
software). However, undocumented attributes may change without notice
in future Klipper releases.

### Variables

The SET_GCODE_VARIABLE command may be useful for saving state between
macro calls. For example:

```
[gcode_macro start_probe]
variable_bed_temp: 0
gcode:
  # Save target temperature to bed_temp variable
  SET_GCODE_VARIABLE MACRO=start_probe VARIABLE=bed_temp VALUE={printer.heater_bed.target}
  # Disable bed heater
  M140
  # Perform probe
  PROBE
  # Call finish_probe macro at completion of probe
  finish_probe

[gcode_macro finish_probe]
gcode:
  # Restore temperature
  M140 S{printer["gcode_macro start_probe"].bed_temp}
```

Be sure to take the timing of macro evaluation and command execution
into account when using SET_GCODE_VARIABLE.
