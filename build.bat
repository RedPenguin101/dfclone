echo WAITING FOR PDB > ./build/lock.tmp

odin build game -build-mode:dll -out:./build/game.dll -debug -vet

cd build
del lock.tmp
cd ..

odin build platform -out:./build/run.exe -debug -vet
