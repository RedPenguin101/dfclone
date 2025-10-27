echo WAITING FOR PDB > lock.tmp

odin build game -build-mode:dll -out:./build/game.dll -debug -vet

del lock.tmp

odin build platform -out:./build/run.exe -debug -vet
