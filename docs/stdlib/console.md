# sino.console

Console utilities.

Import:

```sin
import ConsoleIO from "sino.console"
```

## ConsoleIO:input(prompt)

accepts user input from the console

```sin
ConsoleIO:input("Name: ")
|> print()
```

```
Name: John
John
```

## ConsoleIO:number(prompt)

accepts numeric user input from the console

```sin
ConsoleIO:number("How many sandwiches do you want? ")
|> print()
```

```
How many sandwiches do you want? 3
3
```

```
How many sandwiches do you want? three
Invalid number. Please try again.
How many sandwiches do you want?
```

## ConsoleIO:clear()

clears the terminal