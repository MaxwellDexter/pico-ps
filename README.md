# *pico-ps*: a PICO-8 Particle System

This particle system is a lightweight and fast implementation for the fantasy console [PICO-8](https://www.lexaloffle.com/pico-8.php).
Play the web demo here: https://www.lexaloffle.com/bbs/?tid=33987

# Features
 - Continuous emissions (default)
 - Burst emissions
 - Gravity
 - Random colours
 - Speed over lifetime and speed spread
 - Life spread
 - Angles and angle spread
 - Size over lifetime and size spread
 - Emission areas
 - Colour over life
 - Sprite animation
 - Random sprites
 - Object Pooling

## Future Features
I'd like to get these features implemented next:
- ~~Colour over life~~ done!
- Local space emission
- ~~Easier emitter creation~~ done!
- ~~Sprite animation~~ done!
- ~~Emission shapes / emission in area~~ done!
- ~~Embedded smoothing~~ already there
- Further optimisation
- Collision
- ~~Polish up demos~~ done!
- ~~Rework backend to use entity-component system~~ not happening soz

# How To Use
I'd recommend downloading the project and running the `ps-demo.p8` demo to get a feel for the features that the system has. The code can be helpful on how to implement the system into your game, but you can get started quickly by viewing how the `ps-tiny-demo.p8` spawns a particle emitter.

Please look through the code in `ps.lua`, as there are some good comments on what everything does. Copy the code and view in a text editor of your choice, as it gets kinda horizontal.

To use this, please download `ps.lua` and put `#include ps.lua` at the top of your game code. This will include the contents of the code in your code, and you can create emitters wherever you like. Be sure to update and draw the emitters you have, and run the `update_time()` function before updating the emitters (it depends on the udpated time!). Emitters are created through the function in the table like `emitter.create(...)` where `...` are the base arguments required for an emitter. You can set the rest of the parameters through the `ps_set_x` series of functions (detailed below). e.g. `ps_set_speed(e, speed_initial, speed_final, speed_spread)` with `speed_final` and `speed_spread` being optional. There is also a `clone()` function if you want to make a few emitters that are similar.

Here is the high level UML:
![High Level UML for the emitter and particle.](https://github.com/MaxwellDexter/pico-ps/blob/master/readme_images/high-level-uml.png)

The emitter has a list of particles that it tells to update and draw. There are a few more moving parts in here but that's the gist of it. 

## Documentation
### Emitters
The emitter is basically the 'spawner' of the particles. The particle is the thing you see, and the emitter is what makes it appear.
This is why you have to pass in a lot more details to the emitter than you do the particle.
The emitter is set up so you can have multiple running in the same game, either added to your world's entities collection or your game object.
Steps for a successful emission:
1. Construct the emitter once and set the parameters you want use. Check the `spawn_emitter(emitter_string)` function in `ps-demo.p8` to see how to construct.
2. Add the emitter to either your global collection of entities, or your game object
3. Call the `update_time()` function every frame.
4. Call `update()` and `draw()` on the emitter each frame (using the game loop preferably)
5. Voila you have an emitter

#### Emitter Functions
Call these on your emitter. `create` can be called on the emitter type like: `emitter.create(64, 64, 1, 0)`. It is also implied that you pass in the emitter class/table so that lua can use the `self` keyword, like: `my_emitter.start_emit(my_emitter)`.
| Function        | Parameters                                                                               | Usage                                                                                                                                                              |
|-----------------|------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `create()`      | `x`, `y`, `frequency`, `max_p`, `burst` (default: `false`), `gravity` (default: `false`) | The constructor function for an emitter. Have to specify position, frequency and maximum particles. All other features can be set with the setter functions below. |
| `start_emit()`  |                                                                                          | Starts the emitter to emit (create new) particles. If the emitter is set to burst, then it will fire off a burst and stop emitting immediately.                    |
| `stop_emit()`   |                                                                                          | Stops the emitter from emitting. Will not remove the particles or stop them from updating, only stop more from spawning.                                           |
| `is_emitting()` |                                                                                          | Returns true or false if the emitter is currently emitting.                                                                                                        |
| `clone()`       |                                                                                          | Creates a new emitter and copies all of the values on the emitter you called it on.                                                                                |

### Emitter Set Functions
These functions are global and can just be called. Do not call them like `my_emitter.ps_set_pos(my_emitter, x, y)`, just use `ps_set_pos(my_emitter, x, y)`. The `e` parameter is the emitter that you want to set the values on.
| Function | Parameters | Usage |
|-|-|-|
| `ps_set_pos()` | `e`, `x`, `y` | The coordinates of the emitter, particles will spawn from this location. |
| `ps_set_frequency()` | `e`, `frequency` | How frequently you want particles to spawn, uses a "particles per frame" approach. E.g. a frequency of 2 will spawn 2 particles each frame, a frequency of 0.5 will spawn 1 particle every 2 frames. |
| `ps_set_max_p()` | `e`, `max_p` | The maximum number of particles the emitter is allowed to spawn. `0` = unlimited. |
| `ps_set_gravity()` | `e`, `gravity` | Are the particles affected by gravity? Pass in `true` for yes or `false` for no. Will be affected by whatever is in the `calc_gravity(a)` function |
| `ps_set_burst()` | `e`, `burst`, `burst_amount` (default: max_p) | Is this a burst emitter? Pass in `true` for yes or `false` for no. Will make the emitter shoot out particles and then immediately stop emitting. If you're hooking this up to an object that bursts whenever it does something, just call `start_emit()` and it will emit the next burst. `burst_amount` is the amount of particles to emit every time you start the emitter and "burst". |
| `ps_set_pooling()` | `e`, `pooling` | Does this emitter use object pooling? Pass in `true` for yes or `false` for no. Object pooling loads all of the objects it might need as it needs them (lazy) and then will keep re-using them. Uses more memory for a bit less CPU. |
| `ps_set_rnd_colour()` | `e`, `rnd_colour` | Do you want every particle to be a random colour? Pass in `true` for yes or `false` for no. Will use a random pico-8 colour when there is one colour supplied, otherwise will use a random colour from the colours list. |
| `ps_set_rnd_sprite()` | `e`, `rnd_sprite` | Do you want every particle to be a random sprite? Pass in `true` for yes or `false` for no. Will override the sprite animation and use the sprite list to get random sprites from. |
| `ps_set_area()` | `e`, `width` (default: `0`), `height` (default: `0`) | Do you want to use an area for your emission and not just from a point? Specify the width and height of the box and the emitter will center it and spawn from it. Call the function without passing a width or height and it will stop using the area. |
| `ps_set_colours()` | `e`, `colours` | Pass in a list of colours, e.g. `{1, 5, 6}` for the particle to cycle through evenly (colour over life). You can pass in a list with one colour in it to just have the particles use one colour. Also interacts with the `rnd_colour` setter function. |
| `ps_set_sprites()` | `e`, `sprites` | The sprite(s) you want to display. Pass in a list of sprites e.g. `{3, 4, 5}` or `{3}`. If you don't want sprites, don't call the setter or pass in `nil`. When passing more than one sprite, the particle will transition between the sprites in an even manner. To 'hold' a sprite for longer, you can use it more than once like `{45, 45, 45, 46, 47}`. Also interacts with the `rnd_sprite` setter function. |
| `ps_set_life()` | `e`, `life`, `life_spread` (default: `0`) | Set the time (in seconds) it takes for the particle to die. i.e. the time it will stay on screen. Needs a value greater than `0`. Spread adds a randomly calculated addition on top of the supplied life. Value of `0` = same lifetime for every particle, value > `0` = varying lifetimes. |
| `ps_set_angle()` | `e`, `angle`, `angle_spread` (default: `360`) | Set the angle at which the particles will be emitted in degrees. `0` comes out east (right), and it goes anti-clockwise. `90` degrees will be north (up), `180` degrees comes out west (left) etc. Spread allows particles in a random area of the angle. e.g. an angle value of `180` and a spread value of `30` will spawn your particles with an angle anywhere between 180-210. |
| `ps_set_speed()` | `e`, `speed_initial`, `speed_final` (default: `speed_initial`), `speed_spread_initial` (default: `0`), `speed_spread_final` (default: `initial`) | Set the speed of your particles. Can specify a different final speed to make the particles speed up or slow down. You can specify spread to both of the values to apply some random. |
| `ps_set_size()` | `e`, `size_initial`, `size_final` (default: `size_initial`), `size_spread_initial` (default: `0`), `size_spread_final` (default: `initial`) | Set the size of your particles. Can specify a different final size to make the particles grow or shrink. You can specify spread to both of the values to apply some random. |
### Particles
Generally you don't need to touch the particle class, everything is handled through the emitter.
| Parameter       | Meaning                                                                                                                                                                          | Example Value |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|
| `x`             | The `x` coordinate that the particle spawns at                                                                                                                                   | `64`          |
| `y`             | The `y` coordinate that the particle spawns at                                                                                                                                   | `20`          |
| `gravity`       | Is this particle affected by gravity? `true` or `false`                                                                                                                          | `false`       |
| `colour`        | The `colour` it is. Uses PICO-8's colour system                                                                                                                                  | `7`           |
| `sprite`        | The `sprite` it displays. will overwrite the `colour`. `nil` or sprite number.                                                                                                   | `23`          |
| `life`          | The lifetime of the particle. In seconds.                                                                                                                                        | `4`           |
| `angle`         | The angle you want the particle to come flying out at in radians. The range is `0`-`360`. However, `0` angle is coming out at an eastward direction and it travels anticlockwise | `90`          |
| `speed_initial` | The speed you want the particle to start moving at                                                                                                                               | `4`           |
| `speed_final`   | The velocity you want the particle to finish at when it dies                                                                                                                     | `1`           |
| `size_initial`  | The particle's original size                                                                                                                                                     | `0`           |
| `size_final`    | The size you want the particle to grow/shrink to                                                                                                                                 | 5             |
