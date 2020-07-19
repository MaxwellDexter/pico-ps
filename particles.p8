pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
------------------------------
--      particle system     --
--  max kearney april 2019  --
------------------------------

--[[
documentation (tutorial)
hello, welcome to the particle system.
what do you need to know before using this code in your game?
first run the demo to get a feel for what's going on.
then look through the code to actually see what's going on.

start with the particle object, then the emitter object and then the demo code.
the particle is fairly straightforward, it is an object that displays itself and moves itself.
the emitter is the source of all particles, only use this to create particles. it has a huge constructor.
the demo code will be helpful for setting up the emitters and some upkeep of them.

you can delete all the stuff in the 'demo code' section, but please read it to know how it works.
do not delete: the globals stuff marked as don't delete! these are used for time calculations and will break most of the features if deleted.
can replace with your own: gravity calculations or point2d containers

how the time calculations work:
1. the time in the previous update is stored in prev_time.
2. in the next update call, prev_time is taken (minus) from the current time to get the change in time.
3. the change in time (delta_time) is sent to the emitters so that they can update their particle's fields with it.
4. using delta_time means that particles can perform their calculations as they were intended to, regardless of frame rate.
   even if the frame rate was 1 frame per second, particles with a 3 second lifetime will only exist for 3 seconds, even if that is 3 frames.

good luck and happy coding!
contact me on my itch.io page, or find maxwell dexter and contact me through there if you have any questions.

]]

-------------------------------------------------- globals
-- example emitter and demo code (you can delete these)
show_demo_info = true
my_emitters = nil
emitter_type = 1
emitters = {"basic", "angle spread", "size over life", "velocity over life", "gravity", "everything", "water spout", "light particles", "burst emission", "explosion", "sprites!", "varying sprites", "fire"}

-- don't delete globals from here down
prev_time = nil -- for calculating dt
delta_time = nil -- the change in time

-- gravity calculations
jump_height = 30
apex_time = 12
gravity = (2 * jump_height) / (apex_time * apex_time)
jump_vel = sqrt(2 * gravity * jump_height)

function calc_gravity(a)
 a.velocity.y = a.velocity.y + gravity
end

-------------------------------------------------- point2d
--[[
 this is a container class for two points. 
 can be used for coordinates, velocity or anything else that requires 2 parts of data.
]]
point2d = {}
point2d.__index = point2d
function point2d.create(x,y)
 local p = {}
 setmetatable (p, point2d)
 p.x = x
 p.y = y
 return p
end

-------------------------------------------------- particle
--[[

particle tutorial: 
you likely will never come into contact with the particle object in code, all interfacing should be done through the emitter
 unless you are modifying how the particles work.
still have a look at how this works though.

constructor parameters:
(values are numbers unless specified)
x,y:            the coordinates the particle spawns at
colour:         the colour it is. uses pico 8's colour system.
size:           the particle's original size
size_over_life: the size you want the particle to grow/shrink to
speed:          the speed you want the particle to start moving at (try 10)
vel_over_life:  the velocity you want the particle to finish at when it dies
angle:          the angle you want the particle to come flying out at in radians. range is 0-360. 
                 however, 0 angle is coming out at an eastward direction and it travels anticlockwise
gravity:        is this particle affected by gravity? true or false
sprite:         the sprite it displays. will overwrite the colour. nil or sprite number.

]]
particle = {}
particle.__index = particle
function particle.create(x,y, colour, life, size, size_over_life, speed, vel_over_life, angle, gravity, sprite)
 local p = {}
 setmetatable (p, particle)
 p.pos = point2d.create(x,y)
 p.colour = colour
 p.orig_life = life
 p.life = life

 -- the 1125 number was 180 in the original calculation, 
 -- but i set it to 1131 to make the angle pased in equal to 360 on a full revolution
 -- don't ask me why it's 1131, i don't know. maybe it's odd because i rounded pi?
 local angle_radians = angle * 3.14159 / 1131
 p.velocity = point2d.create(speed*cos(angle_radians), speed*sin(angle_radians))
 p.orig_vel = point2d.create(p.velocity.x, p.velocity.y)
 p.vel_over_life = point2d.create(vel_over_life*cos(angle_radians), vel_over_life*sin(angle_radians))

 p.dead = false
 p.gravity = gravity

 p.size = size
 p.orig_size = size
 p.size_over_life = size_over_life

 p.sprite = sprite

 return p
end

-- upodate: handles all of the values changing like life, gravity, size/life, vel/life, movement and dying
function particle:update(dt)
 self.life = self.life - dt

 if (self.gravity) then
  calc_gravity(self)
 end

 -- size over lifetime
 if (self.orig_size ~= self.size_over_life) then
  -- take the difference of original and future, divided by time, multiplied by delta time
  self.size = self.size - ((self.orig_size-self.size_over_life)/self.orig_life)*dt
 end

 -- velocity over lifetime
 if (self.orig_vel.x ~= self.vel_over_life.x) then
  -- take the difference of original and future, divided by time, multiplied by delta time
  self.velocity.x = self.velocity.x - ((self.orig_vel.x-self.vel_over_life.x)/self.orig_life)*dt
  self.velocity.y = self.velocity.y - ((self.orig_vel.y-self.vel_over_life.y)/self.orig_life)*dt
 end

 -- moving the particle
 if (self.life > 0) then
  self.pos.x = self.pos.x + self.velocity.x * dt
  self.pos.y = self.pos.y + self.velocity.y * dt
 else
  self.die(self)
 end
end

-- draws a circle with it's values
function particle:draw()
 if (self.sprite ~= nil) then
  spr(self.sprite, self.pos.x, self.pos.y)
 else
  circfill(self.pos.x, self.pos.y, self.size, self.colour)
 end
end

-- sets flag so that the emitter knows to kill it
function particle:die()
 self.dead = true
end

-------------------------------------------------- particle emitter

--[[
emitter tutorial:
the emitter is basically the 'spawner' of the particles. the particle is the thing you see, and the emitter is what makes it appear.
this is why you have to pass in a lot more details to the emitter than you do the particle.
the emitter is set up so you can have multiple running in the same game, either added to your world's entities collection or your game object.
steps for a successful emission
1. construct the emitter with all of the arguments passed in
   yes, it's huge but if you use the guiding line it will greatly help you to construct your emitters.
   check the 'spawn_emitter(emitter_string)' function to see the constructors with the commented line on top
2. add the emitter to either your global collection of entities, or your game object
3. call update() and draw() on the emitter each frame (using the game loop preferably)
4. voila you have an emitter

constructor parameters:
the names have been shortened for readability
x:        the x coordinate the particles will spawn from
y:        the y coordinate the particles will spawn from
freq:     the frequency between emissions in seconds. 0 will spawn every frame, 1 will spawn one particle every frame
max:      the maximum number of particles the emitter is allowed to spawn. 0 = unlimited.
size:     the initial spawn size of the particle. 
s/l:      size over lifetime; the size the particle will be when it dies.
col:      the colour of the sprite. uses pico 8's colour system
ang:      the angle at which the particles will be emitted in degrees. 0 comes out east (right), and it goes anti-clockwise. 
           90 degrees will be north (up), 180 degrees comes out west (left) etc.
a_sp:     angle spread. choosing to spawn your particles in a random area of angle. e.g. an angle value of 180 and 
           a spread value of 30 will spawn your particles with an angle anywhere between 180-210. see the angle demo (red colour)
speed:    the initial velocity of the particle. 0 won't go anywhere, 1 will be really slow. try 10 and adjust from there
speed_sp: speed spread. random speed between speed and speed + speed_spread. e.g. speed of 10 + speed_spread of 10 will produce
           a speed anywhere between 10 and 20.
v/l:      velocity over lifetime. the velocity (speed) your particle will be traveling at when it dies. a value of 0 will make it
           slow down, a value higher than the given speed value will make it speed up.
life:     the time (in seconds) it takes for the particle to die. i.e. the time it will stay on screen. needs a value greater than 0
life_sp:  life spread. randomness of life length. value of 0 = same lifetime for every particle, value > 0 = varying lifetimes
grav:     are the particles affected by gravity? pass in 'true' for yes or 'false' for no. will be affected by whatever is in the calc_gravity(a) function
burst:    is this a burst emitter? pass in 'true' for yes or 'false' for no. will shoot out particles and then immediately stop emitting.
           if you're hooking this up to an object that bursts whenever it does something, just call 'start_emit()' and it will be ready for the next burst
rnd-col:  do you want every particle to be a random colour? pass in 'true' for yes or 'false' for no. 
sprites:  the sprites you want to display. if you don't want sprites, pass in 'nil'. sprites are passed in as a list table and you can 
           have any number of sprites greater than 0. i.e. pass in '{1}' or '{4, 56, 8, 17}' and the emitter will randomly 
           choose one to pass to each new particle it creates.

]]

-- the constructor has to have a lot of stuff passed in so that it can create it's particles correctly
emitter = {}
emitter.__index = emitter
function emitter.create(x,y, frequency, max_p, 
     p_size, p_size_over_life, p_colour,
     p_angle, p_angle_spread, p_speed, p_speed_spread, p_vel_over_life,
     p_life, p_life_spread, p_gravity, p_burst,
     p_rnd_colour, p_sprites)
 local p = {}
 setmetatable (p, emitter)
 p.particles = {}
 p.to_remove = {}

 p.emitting = true
 p.frequency = frequency
 p.emit_time = frequency
 p.max_p = max_p

 p.pos = point2d.create(x,y)

 -- particle factory stuff
 p.p_size = p_size
 p.p_size_over_life = p_size_over_life
 p.p_colour = p_colour
 p.p_angle = p_angle
 p.p_angle_spread = p_angle_spread
 p.p_speed = p_speed
 p.p_speed_spread = p_speed_spread
 p.p_vel_over_life = p_vel_over_life
 p.p_life = p_life
 p.p_life_spread = p_life_spread
 p.p_gravity = p_gravity
 p.p_burst = p_burst
 p.rnd_colour = p_rnd_colour
 p.p_sprites = p_sprites

 return p
end

-- tells all of the particles to update and removes any that are dead
function emitter:update(dt)
 self.emit(self, dt)
 for p in all(self.particles) do
  p.update(p, dt)
  if (p.dead) then
   self.remove(self, p)
  end
 end
 self.remove_dead(self)
end

-- tells of the particles to draw themselves
function emitter:draw()
 for p in all(self.particles) do
  p.draw(p)
 end
end

function emitter:get_colour()
 if (self.rnd_colour) then
  return flr(rnd(16))
 else
  return self.p_colour
 end
end

-- factory method, creates a new particle based on the values set + random
-- this is why the emitter has to know about the properties of the particle it's emmitting
function emitter:get_new_particle()
 local colour = nil
 if (self.p_sprites ~= nil) then colour = self.p_sprites[flr(rnd(#self.p_sprites))+1] end
 --(x,y, colour, life, size, size_over_life, speed, vel_over_life, angle, gravity, sprites)
 local p = particle.create(self.pos.x, self.pos.y, self.get_colour(self),
     rnd(self.p_life_spread) + self.p_life,
     self.p_size, self.p_size_over_life,
     rnd(self.p_speed_spread) + self.p_speed,
     self.p_vel_over_life,
     rnd(self.p_angle_spread) + self.p_angle,
     self.p_gravity,
     colour
     )
 return p
end

function emitter:emit(dt)
 if (self.emitting) then
  if (self.p_burst) then
   if (self.max_p <= 0) then
    self.max_p = 50 end
   for i=1,self.max_p do
    self.add_particle(self, self.get_new_particle(self))
   end
   self.emitting = false
  else
   self.emit_time = self.emit_time - dt
   if (self.emit_time <= 0 and (self.max_p == 0 or #self.particles < self.max_p)) then
    self.add_particle(self, self.get_new_particle(self))
    self.emit_time = self.frequency
   end
  end
 end
end

function emitter:add_particle(p)
 add(self.particles, p)
end

function emitter:add_multiple(ps)
 for p in all(ps) do
  add(self.particles, p)
 end
end

function emitter:remove(p)
 add(self.to_remove, p)
end

function emitter:remove_dead()
 for p in all(self.to_remove) do
  del(self.particles, p)
 end
 self.to_remove = {}
end

function emitter:start_emit()
 self.emitting = true
end

function emitter:stop_emit()
 self.emitting = false
end

function emitter:is_emitting()
 return self.emitting
end

-------------------------------------------------- demo code (you can delete)
-- these are functions to help the demo run. you can copy/model from here,
-- but most of this stuff isn't strictly necessary for an emitter to run
function draw_demo()
 rectfill(0, 0, 128, 6, 5)
 print(emitters[emitter_type], 1, 1, 7)
 if (show_demo_info) then
  rectfill(0, 91, 128, 128, 5)
  if (emitters[emitter_type] ~= "angle spread") then
   print("use arrow keys to move emitters", 1, 92, 7)
  else print("arrow keys changes angle/spread", 1, 92, 7) end
  print("press z to start/stop emitters", 1, 98, 7)
  print("press x to spawn emitter", 1, 104, 7)
  print("press s/f to cycle examples", 1, 110, 7)
  print("press q to show/hide info", 1, 116, 7)
  print("particles: "..get_all_particles(), 1, 122, 7)
 end
 for e in all(my_emitters) do
  e.draw(e)
 end
end

function get_all_particles()
 local p_count = 0
 for i in all(my_emitters) do
  p_count = p_count + #i.particles
 end
 return p_count
end

function update_demo()
 for e in all(my_emitters) do
  e.update(e, delta_time)
 end
 get_input()
end

function get_input()
 if (btnp(5,1)) then
  if (show_demo_info) then show_demo_info = false
  else show_demo_info = true end
 end

 if (btnp(4, 0)) then
  if (my_emitters[1].is_emitting(my_emitters[1])) then
   for e in all(my_emitters) do
    e.stop_emit(e)
   end
  else
   for e in all(my_emitters) do
    e.start_emit(e)
   end
  end
 end
 if (btnp(5, 0)) then
  spawn_emitter(emitters[emitter_type])
 end

 local x = 0
 local y = 0
 if (btn(0,0)) then
  x =  -1
 elseif (btn(1,0)) then
  x = 1
 end
 if (btn(2,0)) then
  y = -1
 elseif (btn(3,0)) then
  y = 1
 end
 for e in all(my_emitters) do
  if (emitters[emitter_type] ~= "angle spread") then
   e.pos.x = e.pos.x + x
   e.pos.y = e.pos.y + y
  else
   e.p_angle = e.p_angle + -x
   if (e.p_angle_spread > 0) then
    e.p_angle_spread = e.p_angle_spread + y
   else e.p_angle_spread = 1 end
  end
 end

 if (btnp(0,1)) then
  emitter_type = emitter_type - 1
  if (emitter_type < 1) then
   emitter_type = #emitters
  end
  my_emitters = {}
  spawn_emitter(emitters[emitter_type])
 elseif (btnp(1,1)) then
  emitter_type = emitter_type + 1
  if (emitter_type > #emitters) then
   emitter_type = 1
  end
  my_emitters = {}
  spawn_emitter(emitters[emitter_type])
 end
end

function spawn_emitter(emitter_string)
 if (emitter_string == "basic") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,  50,  1,    1,   7,  0,   360,  10,    10,       10,   1,    2,       false, false,  false, nil))
 elseif (emitter_string == "angle spread") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    0,   2,    1,   8,  90,  10,   10,    10,       10,  2,    2,       false, false,  false, nil))
 elseif (emitter_string == "size over life") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0.5,  0,   0,    5,   10,  0,   360,  20,    0,       20,   1,    1,       false, false,  false, nil))
 elseif (emitter_string == "velocity over life") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    0,   1,    1,   11,  0,   360,  0,     0,        50,  2,    0,       false, false,  false, nil))
 elseif (emitter_string == "gravity") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    0,   2,    2,   9,   0,   180,  20,    10,       20,   2,    3,       true, false,  false, nil))
 elseif (emitter_string == "everything") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    0,   4,    0,   12,  0,   360,  20,    20,        0,   1,    4,       false, false,  true, nil))
 elseif (emitter_string == "water spout") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    50,   4,    1,   12,  150,  20,  30,  20,       0,   1,    4,      true, false,  false, nil))
  add(my_emitters, emitter.create(64, 64, 0,    50,   4,    1,   12,  20,  20,  30,  20,       0,   1,    4,      true, false,  false, nil))
  add(my_emitters, emitter.create(64, 64, 0,    50,   4,    1,   12,  60,  20,  30,  20,       0,   1,    4,      true, false,  false, nil))
  add(my_emitters, emitter.create(64, 64, 0,    50,   4,    1,   12,  100,  20,  30,  20,       0,   1,    4,      true, false,  false, nil))
 elseif (emitter_string == "light particles") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(40, 40, 0.2,    0,   2,   0,   10,   0,   360,  20,    10,       0,   2,    1,       false, false,  false, nil))
  add(my_emitters, emitter.create(86, 40, 0.2,    0,   2,   0,   10,   0,   360,  20,    10,       0,   2,    1,       false, false,  false, nil))
  add(my_emitters, emitter.create(64, 80, 0.2,    0,   2,   0,   10,   0,   360,  20,    10,       0,   2,    1,       false, false,  false, nil))
 elseif (emitter_string == "burst emission") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 90, 0,    20, 0,    3,   15,  70,  40,   10,    10,       15,   1,    3,      false, true,  false, nil))
 elseif (emitter_string == "explosion") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    50,   1,    0,   5,   0,   360,  20,    10,       0,   1,    2,      false, true,  false, nil))
  add(my_emitters, emitter.create(64, 64, 0,    50,   3,    0,   8,   0,   360,  20,    10,       0,   0,    2,      false, true,  false, {10,11,12}))
  add(my_emitters, emitter.create(64, 64, 0,    50,   3,    0,   8,   0,   360,  15,    10,       0,   0,    1.5,      false, true,  false, {13,14,15}))
 elseif (emitter_string == "sprites!") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0,    0,   2,   0,   10,   0,   360,  20,    10,       0,   2,    1,       false, false,  false, {1}))
 elseif (emitter_string == "varying sprites") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 64, 0.1,    0,   2,   0,   10,   60,   60,  5,    25,       0,   1,    5,       false, false,  false, {2,3,4,5,6,7,8}))
 elseif (emitter_string == "fire") then
  --                              x   y   freq  max  size  s/l  col  ang  a_sp  speed  speed_sp  v/l  life  life_sp  grav  burst  rnd-col, sprites
  add(my_emitters, emitter.create(64, 80, 0.1,    30,  2,    0,   8,   60,  60,   10,    10,       5,   2,    3,      false, false,  false, nil))
  add(my_emitters, emitter.create(64, 80, 0.2,    30,  2,    0,   8,   60,  60,   5,    10,       0,   2,    0,      false, false,  false, {16,17}))
  add(my_emitters, emitter.create(64, 80, 0.2,    30,  2,    0,   8,   60,  60,   5,    10,       5,   2,    3,      false, false,  false, {18,19,20,21}))
 end
end

-------------------------------------------------- system functions
function _init()
 prev_time = time()
 delta_time = time()-prev_time
 my_emitters = {}
 emitter_type = 1
 spawn_emitter(emitters[emitter_type])
end

function _draw()
 cls()
 draw_demo()
end

function _update60()
 delta_time = time()-prev_time
 update_demo()
 prev_time = time()
end
__gfx__
0000000000a99a0000022000000bb000000aa0000009900000088000000ee0000001100009898980006060000060600000600000080000000880000000000000
000000000a9aa9a0002c720000bc7b0000ac7a00909c7909008c780000ec7e00001c710000009000006760000766660006760000898000008998000000888800
00700700a9a7aa9a0027720000b77b0000a77a00909779090087780000e77e000017710000008000667676606676766067676000080000008998000008899880
000770009a7a7aa900022022000bb000a00aa00a0909909000088000000ee0001001100100009000076767000667660006760000000000000880000008999980
000770009aa7a7a9022222200bbbbbb0a0aaaa0a009999000888888000eeee001001100100008000667676606676766000600000000000000000000008999980
00700700a9aa7a9a220220000b0bb0b00a0aa0a0000990008008800800eeee000111111000009000006760000666670000000000000000000000000008899880
000000000a9aa9a000022000000bb000000aa000000990000008800000eeee000001100009008000006060000060600000000000000000000000000000888800
0000000000a99a000020020000b00b0000a00a00009009000080080000e00e000010010000890000000000000000000000000000000000000000000000000000
0000a000000000000880000008880000008000000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0089a900008080000898000089000000089000008090000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0989a980008080800098000008900000890000008900000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09898980808080800980000000800000080000000889000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88898888888080888800000008900000000000000098000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888888880888980000089000000000000000980000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880088888800098000008800000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800008888000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
55555555555555555555555555555555e55555555555555555555555555588855595555555555555555555555555555555555555555555555555555555555555
57775757577757775757577757575777577555775555555555555555555558555555555555555555555555555555555555555555555555555555555555555555
575557575755575757575575575755755757575555555555e5555555555555555555555555555555555555555555555555555555555555555555555555575555
577557575775577557775575577755755757575555555555555555555555555555555555b5555555555555555555555555555555555555555555555555777555
575557775755575755575575575755755757575a5555555555555555555555555555555bbb555555555555555555555555555555555555555555555555575555
5777557557775757577755755757e777575757aaa5555555555555555555555555555555b5555555555555555555555555555555555555555555555555555555
555555555555555515555555555555555555555a5555555555555555555555555555555555555555555555555555555555555555c55555555555555555555555
00000000000000000000000000003000000000000000000000000000000000000000000000000000000009990000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000099999000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000099999000000000000000000000000000000000000000
00000000000000000000000000000000000007000000000000000000000000000000000000000000000099999000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000fff00000000000009990000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000002000000000000fffff000000000000000000000000000000000000f00000000000000f000
00000000000000000000000000000000000000000000000000000022200000000000fffff0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000002000000100000fffff0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000011100000fff00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000
0000000008000000000000000000000000000000000000000006000000000000000000000000000000000000eee000000000000000000000000000000000000b
000000000000000000000000000000000000000000000000000000000000000004000000000000000000000eeeee0000000000000000000000000000000000bb
00000000000000000000000000000f000000000000000000000000000000000044400000000000000000000eeeee00000000000000000000000000000000000b
000000000000000000000000000000000000000000000fff000000000000000004000000000000000000000eeeee00000000000000000000000000000000000d
00000000000000000000000000000000000000000000fffff000000000000000000000000000000000000000eee0000000000000000000000000000000000000
00000000000000000000000000000000000000000000fffffd000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000002000000000000000000002220000000000fffffdd00000000000000000000000000000000000000000000005000000000000000000000000000000
000000000222000f00000000000000522220000000000fffddd0000000000000000e0000000000000000000000200000555000000000000a0000000000000000
0000000000200000000000000000055522200000000000ddddd000000000000000eee00000000000000000000222000005000000000000000000000000000000
000000000000000000000000000040522220000000000001dd000000b0000000000e000000088800004000000020008000000000700000000000000000000000
00000000000000000000000000046662220000000000001110000000000000000000000000888880044400000006488800000007770000000000000000000000
00000000000000000000000000066666000000000777000100000000000000000000000008888888004005000066648000000000700000000000002000000000
00000000000000000000000000066666000000007777000000000700000000000000000008888888700000000006400000003007000000000000022200000000
0000000000000000000000000006666600000000777000000000000000000ccc0000000008898888770000000000000000000000000000000000002000000000
000000000000000000000000000066600000000077700080000000000000c999c000000000999880700000000000000000000000000000000000000000000000
000000000000000000000000000000000000000007700888000000b0000099999000000000098800000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000008000000000000999999900000000000000000000000000000000000000000000000000000000000000
000000000000000300000000000000000000001c222000000006000ccc0999999000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000e0222220000002220777cc999990000000000000000000000300000000000000000000000000000000000000000
7000000000000000000000000000000000000002222200000222277777cc99900000000000000080000003330001110000000000000000000000000000000000
0000000000000000000000000090000055500002222200002222277777cc0990000000000000004440000030c011111008000000000000000000000000000000
000000000000000000000000099900055c550000222700002222977777cddd0000000000000004444400000ccc1e311000000000000000000000000000000000
00000000000000000000000000900005ccc50000777770002229997779ddddd0000000000000044444000000c0eee310f000000a000005000000000000000000
000000000000000000000000088800055c55000077777000022999999ddddddd000000000000044444000000000e366600000000000055500000000000000000
0050000000000000000000008888eee055500000777770000029999bbddddddd0000000000000044c00000000000666660000000000005000000000000000000
055500000000000000000000888eeeee0000000007770000ddd099bbbddddddd0000bbb66600000ccc0b00000000666660000000000000000000000700000000
005000000000000000000011188eeeee00000000000000888d888bbbbbddddd5000bbb6666600000c0bbb0000000666660000000000000000000000000000000
000000000000000000000111118eeeee000000000000088111888bbbbbbddd0000cccb6666600000000b10000000066600000000000000000000000000000000
0000000000000000000001111100eee0000000000000881111188bbbbbbb6bbb0ccccc6666600000000111033300000000000000000000000000000000000000
00000000000000000000011111000000000000d000008811111888bbbbb6bbbbbcccccb666000000011110333330000010040000000000000000000000000000
0000000000000000000000111000000000000ddd000088111117788bbb6bbbbbbbcccc0000002000777111333330000111000000000000000000000000000000
00000000000000000000000000000000000000deee005551117777aac66bbbbbbbccc6600002220777771133333000001000e000000000000000007770000000
00000000000000000000000000000033300000eeeee555557777777aaa0bbbbbbbaaa660000020777777711333000000000eee00000000000000077777000000
0000000000000000000000000000033333000eeeeee555557777777aaaa0bbbbbaaaaa660000007777777111100000000000e000000000000000077777000000
0000000000000000000000000000033333000ee5eee566657222777aaaa06bbba555aad660000777777771110000000000000000000000000000077777000000
000000000000f000000000000000033333000eeeeee6ddd6222227aaa555eeea55555ad66000077777774400000000000000000000000c000000007770000000
00000000000fff000000000000000033300d00eeeeeddddd222227aa55555ee5555555d600000777777444ccc000000f000000000000cc700000000000000000
000000000000f00000000000000000000000eeeeeeddddddd22277755555559ddd55556000000077444444cccc0000f00000000000000c000005000000000000
000000000000000000000e0050000000000eeee100ddddddd22227c5555559ddddd55888ff00009888444ccccccee00000000000000000000055500000000000
00200000000000000000000555000000000eee1110ddddddd222222555559ddddddd88888ff009888884ccaaacceee0000000000000000000005000000000000
0000000000000000000000005000a000000eeaa10b0ddddd4222222b55559ddddddd888888f008888888caaaaaceee000000a000000400000000000000030000
a00000000000000000000000000aaa100000eea00000ddd56642222bb55ddddddddd888888fbb88888884aaaaaeeee0000000000000000000000000000000000
0000000000000000000000000000a0000000000000000055566222cc1cdd000dddd88888880bb88888884aaaaaeee000000bbb00000000000000000000000000
0000000000000000000ccc00000000000000000000000065666222cc1dd00000ddd088888bb0aa88ddd444aaa222200000bbbbb0000000000000000000000000
000000000000000000ccccc0000000000000000000000066666022cc1d00000555dd5888abbaaaaddddd40042222203000bbbbb0000000000000000000000000
000000000000000000ccccc000000000eee00000000000666600022ccd000055555dd566aaa77aadddd777444222000000bbbbb0000000000000000000000000
000000000000000000ccccc00000000eeeee0000afff066666000000cc0005555555d56aaaaa77addd77777400000000000bbb00000500000000000000000000
0000000000000000006ccc00000000eeeeeee00afffff666666f0444000005555555eddaaaaaa77ad77777770000002220000000005550000000000000000000
000000000000000000060000000000eeeeeee0aaffff666666622244aaa005555555edddaaaaa77ad77777770000022222000000000500000000000000000000
000000000000000000000000000000eeeeeee0aafff666666622222aaaaab755555eeddddaaaa775077777770000022222000000000000000000000000000000
000000000000000000000d000000000eeeee00aaaff66666662222aaaaabb77555eedddddaaa7755507777700f2222222200000000000000000000f000000000
000000000000000f0000ddd000000000eee0000aaaa66666662222aaaaabb777eee7dddddaa777555007779bf222222220000000000000000000000000000000
000000000000000000000d000000000000000000aaa06666622222aaaaabbb77777ddddd0777775fff0009bbb222220000000000000000000000000000000000
000000000000000000000000000000000000000000000666c322222aaaaabbb77700ddd0077777fffff0009bf222220000022200000000000000000000000000
00000000000000000000000000000ccc00000000f0000000cc322255aaa13bbb3330000077777fffffffaaa88f22280000222220000000000000000000000000
0000000000000000000000000000ccccc000000ff0000000cc35555522213333333b000297779fffffaaaaaa8888880000222f20000000000000000000000000
000000000000100000000000000ccccccc00000fff0000000c0055522f0133333334442666669ffffaaaa7778888880000222220000000000000000000000000
000000000000000000000000000ccccccc00000fff00000000000022fff0133333444466666660fffaaa777778888000000222000000000c0000000000000000
000000000000000000000051000ccccccc000000fff000000000d8990f000133344446666666661ffaa77777778800000000000c000000ccc000000000000004
0000000000000000000005553330ccccc00000000d000000000d888990009999b44446666666665110a77777770002220000000d0000000c0000000000000044
00000000000000000000075333330ccc000000000000000000dd88889990999994444666666666ae11b7777777002222200000ddd00000000000000000000004
00000000000000000000777333330000000000000000000000dd88888880c9999944446666666eee110b7777700022222800a00d000000000000000000000000
00000000000200000d0077733333005550000000fff0000000d998888800cc999dd444166666eeee1100077700002222c000e000000100000000000000000000
0000000000000000ddd07777333005555590000fffff09990099998880000cddddddd15555557ee1100000000000022ccc0eee00001110000000000000000000
d0000000000000000d000777000005555599000fffff9999909ddd905550002ddddd005555577e110000000000000000c000e000000100000000000000000000
000000000000000006000000000005555599000fffff999990ddddd555550000dd90001555557000000000000000111000007000000000000001000000000000
0000000000000000666000000000005559990444fff0999990ddddd5555550000999001155555000000111000001111100000000000000000011100000000000
00000000000000000600000000000000999044444000099900ddddd5555550ccc09000015999500000111110000111110000000000000000c001000000000000
000000000000000000000000000000000000444443000005000ddd5555555c888c000000999991000111111100011111000000000000000ccc00000000000000
000000000f0000000000000000000000000444444000000000000105555333888800000099999b1001111111000011100000f00000000000c000000000000000
000000000000000000000000000000000004444400000000000011105533333888000eee99999bb00111111150000000000fff00000000000000000000000005
00000000000000000000000000000000000444440a00000000000100003333388800eeeeb999bbb00b111115500000000000f000000000000000000000000055
0000000000000000000000000000000000004440aaa0000000000000003333388000eeeebbbbbbbcbbb111555010000000000000000000000000000000000005
0000000000000000000000000000ccc0000000000a0999000000077600a333110000eeee7bbbbbc0bbbee5550000000000000000000000000000000000000000
000000000000000000000000000ccccc0000000000999990000077777aaa111000000eee07bbb00ebbeeeee00000000000000000000000000000000000000000
00000000000000000000000000000ccc00000000009999900000777774a4400000000000000000eeebeeeeec0000000000000000000000000000000000000000
000000000000000000000000000000cc00000050009999900000777774444000000000000000000e00eeeee00000000000000000000000000000000000010000
000000000000000000000000100000c000000555000999000000077744444000000000000000000000deeed00000020200000000000000000000000000111006
0000000000000000000000011000000000000050000000000000d7ddd44400000000001110000000000ddd000000222000000000000000000000000000010000
000000000000000000000000100000000000000000000000000ddddddd00000000000b1111000000000000000000020000000000000000000000000000000000
000000000000000000000000008000000000000000000004000ddd222d0000000000bbb1110000000000000000000000000000000000000000ccc00000000000
00000000000000000000000008880000000000000000d022200dddddddd0000000000b1111000000000006000c08000000000000000e00000ccccc0000000000
0000000000000000000000000080000000000000000ddd222200dddddd000000000000222000000000006660000000000000000000eee0000ccccc0000000000
00000000b00000000000000000000044400000000003d2222200ddddd20000001000022222000000000006000000000000000000000e00000ccccc0000000000
00000000000000000000000000000444440000307733322c2200ddddd000006111000222220000000000000000000000000000000010000000ccc00000000000
00000000000000000000000000000444440003377773002220000ddd000006661000022222000000000000000000000000400000011100000000000000000000
00000000000000000000000600000444440000377777000b00000000000000600000002228000040000000008880000004440000001000000000000000000000
0000000000000000000000e660000044400000077777000d000000d0000000000000000080000444000000088888000000400000000000000000000000000000
000000000000000000000eee0000000000000000777000ddd0000ddd0050000000000000000000400000000eee88000000000000000000000000000000000000
0000000000000000000000e000000000000000000000000ddd0000d0000b00000000000000000000000000eeeee8000000000000000000000000000000000000
000000000000000000000e000000000000000000000000ddddd0000000bbb0000000000000000000000000eeeee000000000c0000000000000000000000b0000
0000000000000000000000000000000000000000000000ddddd00000000b00000000000000000000000000eeeee0000000000000000000000000000000bbb000
0000000000000000000000000000000000000000000000ddddd0000000000000000000000000d0000000000eee000000000000000000000000000000000b0000
00000000000000000000000000000000000000000000000ddd000002000000004000000000000d00000000000000000000000000bbb000000000000000000000
0000000000000000000000000000000000000000000000044400000000000004440000000000d00000000080000000000000000bbbbb00000000000000000000
0000000000000000000000000000000000000000000000004000000000000000400d00000000000000000888000000000000000bbbbb00000000000000000000
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000080000000000000000bbbbb00000000000000000000
0000000000000000000000000000000000000000000d000000000000000000000000000000000003000000000000000000000000bbb000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000003000000000033300000000006000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000003000000000066600000000000000000000000000000000000
00000000000000060000000000000000000000000000000000000000000000000000600000000000000000000006000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000f00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000006660000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000006000000000000000000b0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000bbb000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000b0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

