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

Command | Description
---- | ----
print *String* | Prints to stdout
*Integer* = add *Integer* *Integer* | Adds two Integers
*Float* = add *Float* *Float* | Adds two Floats
*String* = add *String* *String* | Concatenates two Strings
*Integer* = sub *Integer* *Integer* | Subtracts two Integers
*Float* = sub *Float* *Float*| Subtracts two Floats  
*Integer* = mult *Integer* *Integer* | Multiplies two Integers
*Float* = mult *Float* *Float* | Multiplies two Floats
*Integer* = div *Integer* *Integer* | Divides two Integers
*Float* = div *Float* *Float* | Divides two Floats 
*Integer* = strlen *String* | Returns the lengths of a string
*Integer* = integer *Any* | Converts to Integer
*Float* = float *Any* | Converts to Float
stop | Stops script execution
call *Integer* | Calls subroutine
return | Returns from subroutine
*Float* = eval *Any* ... *Any* | Returns the result of a numeric expression

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

New commands can be added to a EMILRuntime object using the ```registerCommand``` method:

```
let _ = runtime.registerCommand("f fact f", handler: emilFactorial)
```

### Signatures

The first parameter is the so-called signature. The signature defines the types of the return value (if any) and the arguments to the command. The types are

- **i**: Integer
- **f**: Float
- **s**: String
- **o**: Operator
- **x**: Any type

The general signature format is

```[f|i|s|x]``` ```<command name>``` ```[f|i|s|x]``` ... ```[f|i|s|x]``` ```[:]```

- On first character defines the return value type (if applicable)
- Followed by the command name
- Then one type character per argument

One special character is the **:**. It can only be the last character in the type list and denotes that any number of arguments can follow (= variable argument list). All arguments are the assumed of type **x** (= Any).

Examples:

- ```f add ff```: Command *add* takes two Float arguments and returns one Float value
- ```print s```: Command *print* takes one String argument and returns nothing
- ```f eval :```: Command *eval* takes any number arguments of type Any and returns one Float value

### Command implementation

For each command a handler function has to be implemented:

```func handler(_ program: EMILProgram, cmd: Command) -> CommandStatus```

- **program**: The current EMIL program context
- **cmd**: The current command object

**EMILProgram** offers the following methods
- ```func getArgument(_ command: Command, num argnum: Int) -> Variable?```: The argument number *argnum*
- ```func numArguments(_ command: Command) -> Int```: Returns number of passed arguents
- ```func setReturn(_ command: Command, val: Variable) -> Bool```: Set the return value

Example implementing a *fact* command calculating the factorial of the given argument:

```
func emilFactorial(_ program: EMILProgram, cmd: Command) -> CommandStatus {
    if let arg = program.getArgument(cmd, num: 0) {
        if case let .varFloat(val) = arg {
            var mult = val
            var retVal: Double = 1.0
            while mult > 0.0 {
                retVal *= mult
                mult -= 1.0
            }
            if program.setReturn(cmd, val: .varFloat(retVal)) == false {
                return .failure
            }
            return .success
        }
    }
    return .failure
}
```




