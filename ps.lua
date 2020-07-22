---------------------------
--        pico-ps        --
--    particle system    --
--  author: max kearney  --
--  created: april 2019  --
--  updated: july 2020   --
---------------------------

--[[
documentation (tutorial)
hello, welcome to the particle system.
what do you need to know before using this code in your game?
first, run the demo to get a feel for what's going on.
then look through the code to actually see what's going on.

start with the particle object, then the emitter object and then the demo code.
the particle is fairly straightforward, it is an object that displays itself and moves itself.
the emitter is the source of all particles, only use this to create particles. fyi it also has a huge constructor.
the demo code will be helpful for setting up the emitters and some upkeep of them.
you can replace these with your own: gravity calculations or point2d containers

please remember to update the variables 'prev_time' and 'delta_time' in your update loop!

how the time calculations work:
1. the time in the previous update is stored in prev_time.
2. in the next update call, prev_time is taken (minus) from the current time to get the change in time.
3. the change in time (delta_time) is sent to the emitters so that they can update their particle's fields with it.
4. using delta_time means that particles can perform their calculations as they were intended to, regardless of frame rate.
   even if the frame rate was 1 frame per second, particles with a 3 second lifetime will only exist for 3 seconds, even if that is 3 frames.

good luck and happy coding!

feel free to contact me if you have any questions.
itch: https://maxwelldexter.itch.io/
twitter: @KearneyMax
]]

-------------------------------------------------- globals

prev_time = nil -- for calculating dt
delta_time = nil -- the change in time

function update_time()
 delta_time = time()-prev_time
 prev_time = time()
end

gravity = 50

function calc_gravity(a)
 a.velocity.y = a.velocity.y + delta_time * gravity
end

-------------------------------------------------- point2d
--[[
 this is a container class for two points (a vector). 
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

constructor parameters: (values are numbers unless specified)
- x, y:           the coordinates the particle spawns at
- gravity:        is this particle affected by gravity? true or false
- colour:         the colour it is. uses pico 8's colour system.
- sprite:         the sprite it displays. will overwrite the colour. nil or sprite number.
- life:           the lifetime of the particle. in seconds.
- angle:          the angle you want the particle to come flying out at in radians. range is 0-360. 
                   however, 0 angle is coming out at an eastward direction and it travels anticlockwise
- speed_initial:  the speed you want the particle to start moving at (try 10)
- speed_final:    the velocity you want the particle to finish at when it dies
- size_initial:   the particle's original size
- size_final:     the size you want the particle to grow/shrink to
]]
particle = {}
particle.__index = particle
function particle.create(x, y, gravity, colour, sprite, life, angle, speed_initial, speed_final, size_initial, size_final)
 local p = {}
 setmetatable (p, particle)

 p.pos = point2d.create(x,y)
 p.colour = colour
 p.life_initial = life
 p.life = life

 -- the 1125 number was 180 in the original calculation, 
 -- but i set it to 1131 to make the angle pased in equal to 360 on a full revolution
 -- don't ask me why it's 1131, i don't know. maybe it's odd because i rounded pi?
 local angle_radians = angle * 3.14159 / 1131
 p.velocity = point2d.create(speed_initial*cos(angle_radians), speed_initial*sin(angle_radians))
 p.vel_initial = point2d.create(p.velocity.x, p.velocity.y)
 p.vel_final = point2d.create(speed_final*cos(angle_radians), speed_final*sin(angle_radians))

 p.dead = false
 p.gravity = gravity

 p.size = size_initial
 p.size_initial = size_initial
 p.size_final = size_final

 p.sprite = sprite

 return p
end

-- update: handles all of the values changing like life, gravity, size/life, vel/life, movement and dying
function particle:update(dt)
 self.life = self.life - dt

 if (self.gravity) then
  calc_gravity(self)
 end

 -- size over lifetime
 if (self.size_initial ~= self.size_final) then
  -- take the difference of original and future, divided by time, multiplied by delta time
  self.size = self.size - ((self.size_initial-self.size_final)/self.life_initial)*dt
 end

 -- velocity over lifetime
 if (self.vel_initial.x ~= self.vel_final.x) then
  -- take the difference of original and future, divided by time, multiplied by delta time
  self.velocity.x = self.velocity.x - ((self.vel_initial.x-self.vel_final.x)/self.life_initial)*dt
  self.velocity.y = self.velocity.y - ((self.vel_initial.y-self.vel_final.y)/self.life_initial)*dt
 end

 -- moving the particle
 if (self.life > 0) then
  self.pos.x = self.pos.x + self.velocity.x * dt
  self.pos.y = self.pos.y + self.velocity.y * dt
 else
  self.die(self) -- goodbye world
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

constructor parameters: (names have been shortened for readability)
- x:                the x coordinate the particles will spawn from
- y:                the y coordinate the particles will spawn from
- frequency:        the frequency between emissions in seconds. 0 will spawn every frame, 1 will spawn one particle every frame
- max_p:            the maximum number of particles the emitter is allowed to spawn. 0 = unlimited.
- burst:            is this a burst emitter? pass in 'true' for yes or 'false' for no.
                     will make the emitter shoot out particles and then immediately stop emitting.
                     if you're hooking this up to an object that bursts whenever it does something,
                      just call 'start_emit()' and it will be ready for the next burst
- gravity:          are the particles affected by gravity? pass in 'true' for yes or 'false' for no.
                     will be affected by whatever is in the calc_gravity(a) function
- rnd_colour:       do you want every particle to be a random colour? pass in 'true' for yes or 'false' for no. 
- p_colour:         the colour of the sprite. uses pico 8's colour system
- p_sprites:        the sprites you want to display. if you don't want sprites, pass in 'nil'. 
                     sprites are passed in as a list table and you can have any number of sprites greater than 0.
                     i.e. pass in '{1}' or '{4, 56, 8, 17}' and the emitter will randomly choose one to pass to 
                      each new particle it creates.
- p_life:           the time (in seconds) it takes for the particle to die. i.e. the time it will stay on screen. 
                     needs a value greater than 0
- p_life_spread:    life spread. randomness of life length.
                     value of 0 = same lifetime for every particle, value > 0 = varying lifetimes
- p_angle:          the angle at which the particles will be emitted in degrees. 
                     0 comes out east (right), and it goes anti-clockwise. 
                     90 degrees will be north (up), 180 degrees comes out west (left) etc.
- p_angle_spread:   angle spread. choosing to spawn your particles in a random area of angle.
                     e.g. an angle value of 180 and a spread value of 30 will spawn your particles with
                      an angle anywhere between 180-210. see the angle demo (red colour)
- p_speed_initial:  the initial velocity of the particle.
                     0 won't go anywhere, 1 will be really slow. try 10 and adjust from there
- p_speed_final:    The velocity speed your particle will be travelling at when it dies.
                     a value of 0 will make it slow down, a value higher than the given speed value will make it speed up.
- p_speed_spread:   speed spread. random speed between speed and speed + speed_spread.
                     e.g. speed of 10 + speed_spread of 10 will produce a speed anywhere between 10 and 20.
- p_size_initial:   the initial spawn size of the particle.
- p_size_final:     the size the particle will be when it dies.
- p_size_spread:    the variance (spread) in the size for the particles. leave as 0 to turn off
]]

-- the constructor has to have a lot of stuff passed in so that it can create it's particles correctly
emitter = {}
emitter.__index = emitter
function emitter.create(x,y, frequency, max_p, 
     burst, gravity, rnd_colour,
     p_colour, p_sprites,
     p_life, p_life_spread,
     p_angle, p_angle_spread,
     p_speed_initial, p_speed_final, p_speed_spread,
     p_size_initial, p_size_final, p_size_spread
     )
 local p = {}
 setmetatable (p, emitter)
 p.particles = {}
 p.to_remove = {}

 -- emitter variables
 p.pos = point2d.create(x,y)
 p.emitting = true
 p.frequency = frequency
 p.emit_time = frequency
 p.max_p = max_p
 p.gravity = gravity or false
 p.burst = burst or false
 p.rnd_colour = rnd_colour or false
 p.use_area = false
 p.area_width = 0
 p.area_height = 0

 -- particle factory stuff
 p.p_colour = p_colour or 7
 p.p_sprites = p_sprites or nil
 p.p_life = p_life or 1
 p.p_life_spread = p_life_spread or 0
 p.p_angle = p_angle or 0
 p.p_angle_spread = p_angle_spread or 360
 p.p_speed_initial = p_speed_initial or 10
 p.p_speed_final = p_speed_final or 10
 p.p_speed_spread = p_speed_spread or 0
 p.p_size_initial = p_size_initial or 1
 p.p_size_final = p_size_final or 1
 p.p_size_spread = p_size_spread or 0

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
 local sprite = nil
 -- select random sprite from the sprites list
 if (self.p_sprites ~= nil) then sprite = self.p_sprites[flr(rnd(#self.p_sprites))+1] end

 local speed_spread = rnd(self.p_speed_spread)
 local size_spread = rnd(self.p_size_spread)

 local x = self.pos.x
 local y = self.pos.y
 if (self.use_area) then
  -- center it
  local width = self.area_width
  local height = self.area_height
  x += flr(rnd(width)) - (width / 2)
  y += flr(rnd(height)) - (height / 2)
 end

 --(x,y, gravity, colour, sprite, life, angle, speed_initial, speed_final, size_initial, size_final)
 local p = particle.create
 (
  x, y, -- pos
  self.gravity, -- gravity
  self.get_colour(self), sprite, -- graphics
  self.p_life + rnd(self.p_life_spread), -- life
  self.p_angle + rnd(self.p_angle_spread), -- angle
  self.p_speed_initial + speed_spread, self.p_speed_final + speed_spread, -- speed
  self.p_size_initial + size_spread, self.p_size_final + size_spread -- size 
 )
 return p
end

function emitter:emit(dt)
 if (self.emitting) then
  if (self.burst) then -- burst!
   if (self.max_p <= 0) then
    self.max_p = 50 end
   for i=1,self.max_p do
    self.add_particle(self, self.get_new_particle(self))
   end
   self.emitting = false
  else -- we're continuously emitting
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

function emitter:set_pos(x, y)
 self.pos = point2d.create(x,y)
end

function emitter:set_frequency(frequency)
 self.frequency = frequency
end

function emitter:set_max_p(max_p)
 self.max_p = max_p
end

function emitter:set_gravity(gravity)
 self.gravity = gravity
end

function emitter:set_burst(burst)
 self.burst = burst
end

function emitter:set_rnd_colour(rnd_colour)
 self.rnd_colour = rnd_colour
end

function emitter:set_area(use_area, width, height)
 self.use_area = use_area
 self.area_width = width or 0
 self.area_height = height or 0
end

function emitter:set_colour(colour)
 self.p_colour = colour
end

function emitter:set_sprites(sprites)
 self.p_sprites = sprites
end

function emitter:set_life(life, life_spread)
 self.p_life = life
 self.p_life_spread = life_spread or 0
end

function emitter:set_angle(angle, angle_spread)
 self.p_angle = angle
 self.p_angle_spread = angle_spread or 0
end

function emitter:set_speed(speed_initial, speed_final, speed_spread)
 self.p_speed_initial = speed_initial
 self.p_speed_final = speed_final or speed_initial
 self.p_speed_spread = speed_spread or 0
end

function emitter:set_size(size_initial, size_final, size_spread)
 self.p_size_initial = size_initial
 self.p_size_final = size_final or size_initial
 self.p_size_spread = size_spread or 0
end
