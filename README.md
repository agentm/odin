odin
====
[odin-engine](https://github.com/schell/odin/tree/master/odin-engine) is a high
level 2d game and application engine. It provides a number of composable GUI
[widgets](https://github.com/schell/odin/tree/master/odin-engine/src/Odin/Engine/New/UI)
and glue code to various useful libraries. It is written on top of
[reflex-sdl2](https://github.com/schell/reflex-sdl2), an FRP over SDL2.

batteries included
------------------
* [reflex-sdl2](https://github.com/schell/reflex-sdl2) provides the main loop
  and the control scheme is familiar FRP if you've used any reflex based hosts.

* [gelatin-sdl2](https://github.com/schell/gelatin/tree/master/gelatin-sdl2)
  is the OpenGL/SDL2 rendering backend. It supports 2d rendering through colors
  and textures.

* [varying](https://github.com/schell/varying) provides smooth FRP-based
  animation.

* [shapes](https://github.com/ublubu/shapes) provides a purely function 2d
  collision detection and physics system.

installation
------------
`odin-engine` depends on

* [sdl2](http://libsdl.org)
* [freetype2](https://www.freetype.org/index.html)

You can install them with the following platform specific steps.

### Mac OS X

Using [homebrew](https://brew.sh/)...

    brew install freetype
    brew install sdl2

### Ubuntu
First install freetype2

    apt-get install libfreetype6

The [sdl2 bindings](https://github.com/haskell-game/sdl2) require an sdl2
install >= 2.0.4, or for special instructions to be followed. Assuming you're
on `Ubuntu >= 16.04`, you can simply run

    apt-get install libsdl2-dev

otherwise please visit the link above and install via their README.

### Windows
Coming soon


building source
---------------
The easiest way to get up and running on the Haskell toolchain is to download
[stack](https://docs.haskellstack.org/en/stable/README/). All of odin's projects
are spec'd out with stack.yaml build files, so picking the correct versions of
libraries is not needed if you follow the stack path.

    git clone https://github.com/schell/odin.git

    cd odin

If you just installed stack, run

    stack setup

Go make some ☕ and then...

    stack build

Drink your ☕, take a walk and then run...

    stack exec mapMaker

contributions
-------------
I welcome any and all contributions. This means bug reports, pull requests or
even [donations through patreon](https://www.patreon.com/schell). This game and
engine will always be free.
