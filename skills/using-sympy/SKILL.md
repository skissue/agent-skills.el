---
name: using-sympy
description: "Performs symbolic mathematics using SymPy in Python. Use when asked to solve equations, do calculus, simplify expressions, work with matrices, or do any symbolic computation."
---

# Using SymPy for Symbolic Mathematics

SymPy is a pure-Python computer algebra system for symbolic math — algebra, calculus, equation solving, matrices, and more.

## Quick Start

```python
from sympy import symbols, solve, diff, integrate, simplify, Eq, Rational, S
x, y, z = symbols('x y z')
```

## Gotchas & Pitfalls

These are critical — violating them produces silent wrong results.

### Use `**` not `^` for exponentiation

`^` is Python's XOR operator, not power:

```python
x**2        # correct
x^2         # WRONG — bitwise XOR
```

### Use `Rational` or `S()` for fractions

Python evaluates `1/3` to `0.333...` before SymPy sees it:

```python
x**Rational(1, 2)   # correct — sqrt(x)
x**(S(1)/2)          # also correct
x**(1/2)             # WRONG — becomes x**0.5 (float)
```

### `==` tests structural equality, not mathematical equality

```python
(x + 1)**2 == x**2 + 2*x + 1   # False! Different internal forms
Eq(x + 1, 4)                     # symbolic equation object
simplify(a - b) == 0             # test if a and b are mathematically equal
```

### Expressions are immutable

Operations return new expressions; they never modify in place:

```python
expr = x + 1
expr.subs(x, 2)   # returns 3, but expr is still x + 1
expr = expr.subs(x, 2)   # reassign to capture result
```

## Symbols and Assumptions

Symbols default to complex. Add assumptions to enable simplifications:

```python
x, y = symbols('x y', positive=True)   # enables sqrt simplification
a, b = symbols('a b', real=True)        # enables real-valued rules
n = symbols('n', integer=True)
```

Without assumptions, SymPy cannot simplify `sqrt(x**2)` to `x` (since x could be negative or complex).

## Core Operations

### Simplification

```python
simplify(sin(x)**2 + cos(x)**2)        # 1
from sympy import expand, factor, cancel, trigsimp
expand((x + y)**3)                       # x³ + 3x²y + 3xy² + y³
factor(x**2 - 1)                         # (x - 1)*(x + 1)
cancel((x**2 - 1)/(x - 1))              # x + 1
trigsimp(sin(x)**2 + cos(x)**2)          # 1
```

### Substitution

```python
expr = x**2 + 2*x + 1
expr.subs(x, 3)                          # 16
expr.subs(x, y + 1)                      # (y + 2)**2
expr.subs([(x, 1), (y, 2)])              # multiple substitutions
```

### Solving Equations

```python
solve(x**2 - 4, x)                      # [-2, 2]
solve(Eq(x + y, 5), x)                  # [5 - y]
solve([x + y - 5, x - y - 1], [x, y])   # {x: 3, y: 2}

# For solution sets (more rigorous):
from sympy import solveset, S as SymSet
solveset(x**2 - 4, x, domain=SymSet.Reals)   # {-2, 2}
```

### Calculus

```python
diff(sin(x) * exp(x), x)                # differentiation
diff(x**4, x, 3)                         # third derivative

integrate(cos(x), x)                     # indefinite integral — sin(x)
integrate(exp(-x**2), (x, 0, oo))        # definite integral — sqrt(pi)/2

from sympy import limit, oo
limit(sin(x)/x, x, 0)                   # 1

from sympy import series
series(cos(x), x, 0, n=6)               # Taylor series
```

### Matrices

```python
from sympy import Matrix
M = Matrix([[1, x], [y, z]])
M.det()                                  # z - x*y
M.inv()                                  # symbolic inverse
M.eigenvals()                            # eigenvalues
M.eigenvects()                           # eigenvectors

# LU decomposition
L, U, perm = M.LUdecomposition()
```

## Numerical Evaluation

### `evalf` for single values

```python
from sympy import pi, sqrt
pi.evalf()                               # 3.14159265358979
pi.evalf(50)                             # 50 decimal places
sqrt(2).evalf()                          # 1.41421356237310

expr = pi * cos(x)
expr.subs(x, 0).evalf()                 # 3.14159265358979
```

### `lambdify` for NumPy integration

Always use `lambdify` to bridge SymPy → NumPy. Never mix SymPy objects with NumPy arrays directly.

```python
from sympy import lambdify
import numpy as np

expr = sin(x) * exp(-x**2)
f = lambdify(x, expr, 'numpy')          # converts to NumPy function

a = np.linspace(0, 10, 100)
f(a)                                     # fast vectorized evaluation
```

For multiple variables:

```python
expr = x**2 + y**2
f = lambdify([x, y], expr, 'numpy')
f(np.array([1, 2]), np.array([3, 4]))    # array([10, 20])
```

## Pretty Printing

```python
from sympy import init_printing, pprint, latex
init_printing()           # enables best available output (Unicode/LaTeX)
pprint(expr)              # Unicode pretty print to terminal
latex(expr)               # LaTeX string representation
```

## Workflow

1. Define symbols with appropriate assumptions up front.
2. Build expressions symbolically — use `Rational` for fractions, `**` for powers.
3. Manipulate with `simplify`, `expand`, `factor`, `solve`, `diff`, `integrate`.
4. Evaluate numerically with `evalf` for single values or `lambdify` for arrays.
5. Never mix SymPy symbolic objects into NumPy code — always convert via `lambdify` first.
