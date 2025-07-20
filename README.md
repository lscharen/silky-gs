# silky-gs

A NES runtime layer for the Apple IIgs computer. See some examples running [here](https://www.youtube.com/@iigsgamedev9752).

# Pre-requisites

* Merlin32 assembler
* Cadius
* An Apple IIgs emulator

# Building

There are `npm` targets for the completed conversions

* `npm run build:smb`
* `npm run build:bf`

The binaries are located in the `games/<target>` folder.

After the binaries are built, they can automatically be added to a disk image by executing `npm run build-image`

# References

* https://www.gridbugs.org/zelda-screen-transitions-are-undefined-behaviour/
