Please note that my code uses the Chunky PNG library. To install the library, enter

gem install chunky_png

on the command line. You will need to do this before using the interpreter or the printer. You can find information 
about the library here: https://rubygems.org/gems/chunky_png

# Piet Interpreter

The file piet.rb contains my Piet interpreter. To run the interpreter, enter

ruby piet.rb image.png

on the command line. Note that image.png must be a PNG file. I've included some test files of my own making. Like
this one, for example!

![](./test/piet_big.png)

# Piet Printer Printer

The file printer.rb creates a PNG which, when run as Piet source code, prints a given input. Running

ruby printer.rb new_file

and inputing text as instructed by the program will create a Piet source code file called new_file.png which will prints 
the given text. Inputing "Zoe Johnston" will create a Piet file not disimilar to printed.png.
