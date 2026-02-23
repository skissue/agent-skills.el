---
name: using-numbat
description: "Runs calculations with physical units and dimensions using the Numbat CLI. Use when asked to do unit conversions, scientific calculations, or dimensional analysis."
---

# Using Numbat from the CLI

Numbat is a statically typed programming language and CLI calculator for scientific computations with first-class support for physical dimensions and units.

## How to Run Numbat

**Always use `numbat -e` to evaluate expressions.** Do not start the interactive REPL — it is an interactive session that cannot be used by the agent.

```bash
numbat -e '30 km/h -> mi/h'
```

For multi-statement calculations, chain with newlines:

```bash
numbat -e 'let ω = 2π c / 660 nm
ℏ ω -> eV'
```

To run a script file:

```bash
numbat script.nbt
```

## Core Syntax

### Unit Conversions

Use the `->` operator to convert between units:

```numbat
120 km/h -> mph          # = 74.5645 mph
1600 kcal / day -> W     # = 77.4815 W
4 million ฿ -> €         # currency conversion
```

### Arithmetic with Units

Units compose naturally through arithmetic:

```numbat
110 km / (1 day + 3 hours)   # = 4.07407 km/h
atan2(30 cm, 1 m) -> deg     # = 16.6992°
sqrt(1.4^2 + 1.5^2)          # = 2.05183
```

### Variables

**Avoid single-letter names that clash with built-in unit aliases.** Numbat's standard library defines short aliases like `m` (meter), `s` (second), `g` (gram), `c` (speed of light), `K` (kelvin), `A` (ampere), `W` (watt), `J` (joule), `N` (newton), `V` (volt), `F` (farad), `T` (tesla), `l` (liter), `h` (hour). Use descriptive names instead:

```numbat
let mass = 17.9 lb            # NOT: let m = 17.9 lb (clashes with metre)
let dist = 500 km              # NOT: let s = 500 km (clashes with second)
let temp = from_celsius(25)    # NOT: let T = ... (clashes with tesla)
```

```numbat
let ω = 2π c / 660 nm
ℏ ω -> eV                    # = 1.87855 eV
```

### Defining Dimensions and Units

```numbat
dimension Length
dimension Velocity = Length / Time

unit quork = 0.35 meter
```

### Converting to a Specific Unit

```numbat
let v1 = 50 km/h
let v2 = 3 m/s -> unit_of(v1)   # = 10.8 km/h
```

### Multiples of a Value

```numbat
6 hours -> 45 min   # = 8 × 45 min
```

### Temperature

Temperature units (°C, °F) have offsets from Kelvin and require special handling.

**Input:** `25 °C` is valid input and converts to Kelvin internally:

```numbat
25 °C                         # = 298.15 K
-40 °F                        # = 233.15 K
```

**Conversion:** Using `-> °C` or `-> °F` returns a plain scalar (not a Temperature):

```numbat
from_celsius(100) -> °F       # = 212
373.15 K -> °C                # = 100
```

**Functions:** Use `from_celsius(n)` / `from_fahrenheit(n)` to create Temperature values from scalars, and `celsius(t)` / `fahrenheit(t)` to extract scalars:

```numbat
let boiling = from_celsius(100)   # = 373.15 K
celsius(boiling)                   # = 100
```

**⚠ Caution with arithmetic:** Adding two °C values does NOT work as expected because both are converted to Kelvin first:

```numbat
10 °C + 1 °C                 # = 284.3 K + 274.15 K = 558.45 K (WRONG!)
10 °C + 1 kelvin             # = 284.15 K (correct: adding a difference)
20 °C - 10 °C                # = 10 K (correct: temperature difference)
```

### Date/Time and Timezones

```numbat
now() -> unixtime_s
now() -> tz("Asia/Kathmandu")
```

## Workflow

1. For quick one-off conversions, use `numbat -e '<expression>'`.
2. For multi-step calculations, use `numbat -e` with newline-separated statements.
3. For complex or reusable calculations, write a `.nbt` script and run it with `numbat script.nbt`.
