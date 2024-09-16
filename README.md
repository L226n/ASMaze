# ASMaze
A fun little maze generator written in assembly, made in 1 day and then rewritten on the next day to look prettier :)\
Uses Wilson's Algorithm (https://weblog.jamisbuck.org/2011/1/20/maze-generation-wilson-s-algorithm) and also a few functions stolen from L3d2\
To run just assemble maze.asm, link and then execute\
```nasm -f elf64 -O1 maze.asm -o maze.out && ld maze.out -o maze && ./maze```
### Keybinds
Arrow keys to move the maze worm\
``+`` and ``-`` to increase / decrease the mazes width\
``=`` and ``_`` to increase / decrease the mazes height\
``r`` to reset the worms position\
``n`` to create a new maze\
``q`` to quit\
