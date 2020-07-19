# *pico-ps*: a PICO-8 Particle System

This particle system is a lightweight and fast implementation for the fantasy console [PICO-8](https://www.lexaloffle.com/pico-8.php), currently around 230 lines of code.

# How To Use
I'd recommend downloading the project and running the `ps-demo.p8` demo to get a feel for the features that the system has. The code can be helpful on how to implement the system into your game, but you can get started quickly by viewing how the `ps-tiny-demo.p8` spawns a particle emitter in just 10 lines (!!).

Please look through the code in `ps.lua`, as there are some good comments on what everything does. Copy the code and view in a text editor of your choice, as it gets kinda horizontal.

To use this, please download `ps.lua` (or `ps-lite.lua` if you're on a char diet) and put `#include ps.lua` at the top of your game code. This will include the contents of the code in your code, and you can create emitters wherever you like. Be sure to update and draw the emitters you have, and run the `update_time()` function (otherwise your emitters won't work! Emitters are created through the function in the table like `emitter.create(...)` where `...` is all of the arguments.

Generally you don't need to touch the particle class, everything is handled through the emitter.
Here is how it generally works:
![High Level UML for the emitter and particle.](https://github.com/MaxwellDexter/pico-ps/blob/master/readme_images/high-level-uml.png)

There are a few more moving parts in here but that's the gist of it. 
## Documentation

# Features
 - Continuous emissions (default)
 - Burst emissions
 - Gravity
 - Random colours
 - Speed over lifetime and speed spread
 - Life spread
 - Angles and angle spread
 - Size over lifetime and size spread

## Future Features
I'd like to get these features implemented next:
- Colour over life
- Easier emitter creation
- Emission shapes / emission in area
- Embedded smoothing
- Further optimisation
- Collision
