# EMIL
Tiny scripting language embeddable into any Swift project

EMIL = **EM**bedded Scr**I**pt **L**anguage

EMIL is written in 100% Swift 4 and only requires the standard Foundation framework. It is meant to be integrated into projects
where a simple, easy to handle scripting language is needed and other available options (like Lua) are already way to complex.

## Features

- Easy to master language: Syntax is a mixture of BASIC and Shell-Script
- Basic variable types: Float, Integer and String
- Basic control flow contructs: if/else/endif, repeat/unil, while/wend and select/case
- Subroutines
- String interpolation
- Easy extension with own commands
- EMIL is first compiled, therefore reasonaly speedy

## Restrictions

- Numeric expressions only as part of the "eval" command
- No local variables (only a single, global context), therefore no recusion!
- Subroutines have no return value
- No structs, classes or anything like that
- No arrays or dictionaries
- No logic operations (like AND, OR ...)

## Usage

### Step 1:

Simply copy both EMILCompiler.swift and EMILRuntime.swift into your project - that's it!

### Step 2:

Extend the EMIL runtime object with your own commands (optional)

```
let runtime = EMILRuntime()
let _ = runtime.registerCommand("f fact f", handler: emilFactorial) // Add factorial command
```

### Step 3:

Create an EMIL object

```
let emil = EMIL(script: script, runtime: runtime)
```

### Step 4:

Compile and run the EMIL program

```
if let program = emil.compile() {
    runtime.run(program)
}
```

## Language Syntax

The basic syntax is very simple

```[Return value]``` ```:=``` ```Command``` ```Argument 1``` ```Argument 2``` ```Argument 3``` ...

### Script sections

#### VAR
```VAR``` is the keyword to declare variables:

```
VAR int i, j, k
VAR str name, address
VAR float pi, temperature
```

#### SUB

```SUB``` is the keyword to declare subroutines:

```
SUB printHello
   print "Hello"
```

#### MAIN

```MAIN``` marks the entry point of the script.

### Assignment

Value assignments are done using the ```:=``` operator

```pi:=3.1415``` or ```len:=strlen("Hallo")

### Conditions

Only simple conditions are allowed:

```<left side value>``` ```<operator>``` ```<right side value>``` 

Examples:

```
if a<10
endif

while i>=5
wend
```

### Numeric expressions

EMIL does not allow implicit numeric expressions but only explicit using the ```eval``` command. EMIL has basic
calculation commands like ```add```, ```sub```,```mult```,```div```. Therefore the following

```
a:=add a b
a:=mult a c
```
is equivalent to

```
a:=eval (a+b)*c
```

### Control flow

EMIL offers the following control flow constructs

```
if <cond>
  ...
else
  ...
endif
```

Loops:

```
while <cond>
  ...
wend
```

```
repeat
  ...
until <cond>
```

To avoid deep nested if/else/endif:

```
select
  case <cond>
    ...
  fallthrough
  case <cond>
    ...
  break
selend
```

Of course all control flow constructs can be nested

### Standard Runtime Commands

TBD

### String Interpolation

Within strings variable names can be put between square brackets:

```
pi:=3.1415
print "Pi is [pi]"
```

will result in 

```Pi is 3.1415```

### String Escaping

The standard percent-escaping canbe used in strings

```
print "%22in quotes%22"
```

will result in 

```"in quotes"```

## Adding own commands

TBD
