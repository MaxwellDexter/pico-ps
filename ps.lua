---------------------------
--        pico-ps        --
--    particle system    --
--  author: max kearney  --
--  created: april 2019  --
--  updated: october 2020   --
---------------------------

--[[
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

ps_gravity = 50

function calc_ps_gravity(a)
 a.velocity.y = a.velocity.y + delta_time * ps_gravity
end

function vec(x,y)
 return {x = x, y = y}
end

-------------------------------------------------- particle
particle = {}
particle.__index = particle
function particle.create()
 local p = {}
 setmetatable (p, particle)
 return p
end

function particle:set_values(x, y, gravity, colours, sprites, life, angle, speed_initial, speed_final, size_initial, size_final)
 self.pos = vec(x,y)
 self.life_initial, self.life, self.dead, self.gravity = life, life, false, gravity

 -- the 1125 number was 180 in the original calculation, 
 -- but i set it to 1131 to make the angle pased in equal to 360 on a full revolution
 -- don't ask me why it's 1131, i don't know. maybe it's odd because i rounded pi?
 local angle_radians = angle * 3.14159 / 1131
 self.velocity = vec(speed_initial*cos(angle_radians), speed_initial*sin(angle_radians))
 self.vel_initial = vec(self.velocity.x, self.velocity.y)
 self.vel_final = vec(speed_final*cos(angle_radians), speed_final*sin(angle_radians))

 self.size, self.size_initial, self.size_final = size_initial, size_initial, size_final

 self.sprites = sprites
 if (self.sprites ~= nil) then
  self.sprite_time = (1 / #self.sprites) * self.life_initial
  self.current_sprite_time = self.sprite_time
  self.sprites_index = 1
  self.sprite = self.sprites[self.sprites_index]
 else
  self.sprite = nil
 end

 self.colours = colours
 if (colours ~= nil) then
  self.colour_time = (1 / #self.colours) * self.life_initial
  self.current_colour_time = self.colour_time
  self.colours_index = 1
  self.colour = self.colours[self.colours_index]
  if (self.colour == nil) then stop() end -- TODO: somehow the colour ends up being nil
 else
  self.colour = nil
 end
end

-- update: handles all of the values changing like life, gravity, size/life, vel/life, movement and dying
function particle:update(dt)
 self.life -= dt

 if (self.gravity) then
  calc_ps_gravity(self)
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

 -- changing the colour
 if (self.colours ~= nil and #self.colours > 1) then
  self.current_colour_time -= dt
  if (self.current_colour_time < 0) then
   self.colours_index += 1
   self.colour = self.colours[self.colours_index]
   self.current_colour_time = self.colour_time
  end
 end

 -- changing the sprite
 if (self.sprites ~= nil and #self.sprites > 1) then
  self.current_sprite_time -= dt
  if (self.current_sprite_time < 0) then
   self.sprites_index += 1
   self.sprite = self.sprites[self.sprites_index]
   self.current_sprite_time = self.sprite_time
  end
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
 elseif (self.colour ~= nil) then
  circfill(self.pos.x, self.pos.y, self.size, self.colour)
 end
end

-- sets flag so that the emitter knows to kill it
function particle:die()
 self.dead = true
end

-------------------------------------------------- particle emitter
emitter = {}
emitter.__index = emitter
function emitter.create(x,y, frequency, max_p, burst, gravity)
 local p = {
  particles = {},
  to_remove = {},

  -- emitter variables
  pos = vec(x,y),
  emitting = true,
  frequency = frequency,
  emit_time = 0,
  max_p = max_p,
  gravity = gravity or false,
  burst = burst or false,
  burst_amount = max_p,
  use_pooling = true,
  pool = {},
  rnd_colour = false,
  rnd_sprite = false,
  use_area = false,
  area_width = 0,
  area_height = 0,

  -- particle factory stuff
  p_colours = {1},
  p_sprites = nil,
  p_life = 1,
  p_life_spread = 0,
  p_angle = 0,
  p_angle_spread = 360,
  p_speed_initial = 10,
  p_speed_final = 10,
  p_speed_spread_initial = 0,
  p_speed_spread_final = 0,
  p_size_initial = 1,
  p_size_final = 1,
  p_size_spread_initial = 0,
  p_size_spread_final = 0
 }
 setmetatable (p, emitter)
 if (p.max_p < 1) then
   p.use_pooling = false end

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
 foreach(self.particles, function(obj) obj:draw() end)
end

function emitter:get_colour()
 if (self.rnd_colour) then
  if (#self.p_colours > 1) then
   return {self.p_colours[flr(rnd(#self.p_colours))+1]}
  else
   return {flr(rnd(16))}
  end
 else
  return self.p_colours
 end
end

-- factory method, creates a new particle based on the values set + random
-- this is why the emitter has to know about the properties of the particle it's emmitting
function emitter:get_new_particle()
 local sprites = self.p_sprites
 -- select random sprite from the sprites list
 if (self.rnd_sprite and self.p_sprites ~= nil) then
  sprites = {self.p_sprites[flr(rnd(#self.p_sprites))+1]}
 end

 local x = self.pos.x
 local y = self.pos.y
 if (self.use_area) then
  -- center it
  local width = self.area_width
  local height = self.area_height
  x += flr(rnd(width)) - (width / 2)
  y += flr(rnd(height)) - (height / 2)
 end

 local p = {}
 if (self.use_pooling and #self.particles + #self.pool == self.max_p) then
  p = self.pool[1]
  del(self.pool, p)
 else
  p = particle.create()
 end

 -- (x, y, gravity, colours, sprites, life, angle, speed_initial, speed_final, size_initial, size_final)
 p.set_values (p, -- self
  x, y, -- pos
  self.gravity, -- gravity
  self.get_colour(self), sprites, -- graphics
  self.p_life + get_rnd_spread(self.p_life_spread), -- life
  self.p_angle + get_rnd_spread(self.p_angle_spread), -- angle
  self.p_speed_initial + get_rnd_spread(self.p_speed_spread_initial), self.p_speed_final + get_rnd_spread(self.p_speed_spread_final), -- speed
  self.p_size_initial + get_rnd_spread(self.p_size_spread_initial), self.p_size_final + get_rnd_spread(self.p_size_spread_final) -- size 
 )
 return p
end

function emitter:emit(dt)
 if (self.emitting) then
  -- burst!
  if (self.burst) then
   if (self.max_p <= 0) then
    self.max_p = 50
   end
   for i=1, self.get_amount_to_spawn(self, self.burst_amount) do
    self.add_particle(self, self.get_new_particle(self))
   end
   self.emitting = false

  -- we're continuously emitting
  else
   self.emit_time += self.frequency
   if (self.emit_time >= 1) then
    local amount = self.get_amount_to_spawn(self, self.emit_time)
    for i=1, amount do
     self.add_particle(self, self.get_new_particle(self))
    end
    self.emit_time -= amount
   end
  end
 end
end

function emitter:get_amount_to_spawn(spawn_amount)
 if (self.max_p ~= 0 and #self.particles + flr(spawn_amount) >= self.max_p) then
  return self.max_p - #self.particles
 end
 return flr(spawn_amount)
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
  if (self.use_pooling) then
   add(self.pool, p)
  end
  del(self.particles, p)
 end
 self.to_remove = {}
end

-- will randomise even if it is negative
function get_rnd_spread(spread)
 return rnd(spread * sgn(spread)) * sgn(spread)
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

function emitter:clone()
 local new = emitter.create(self.pos.x, self.pos.y, self.frequency, self.max_p)
 ps_set_burst(new, self.burst, self.burst_amount)
 ps_set_gravity(new, self.gravity)
 ps_set_rnd_colour(new, self.rnd_colour)
 ps_set_rnd_sprite(new, self.rnd_sprite)
 ps_set_area(new, self.area_width, self.area_height)
 ps_set_colours(new, self.p_colours)
 ps_set_sprites(new, self.p_sprites)
 ps_set_life(new, self.p_life, self.p_life_spread)
 ps_set_angle(new, self.p_angle, self.p_angle_spread)
 ps_set_speed(new, self.p_speed_initial, self.p_speed_final, self.p_speed_spread_initial, self.p_speed_spread_final)
 ps_set_size(new, self.p_size_initial, self.p_size_final, self.p_size_spread_initial, self.p_size_spread_final)
 ps_set_pooling(new, self.use_pooling)
 return new
end

-- setter functions

function ps_set_pos(e, x, y)
 e.pos = vec(x,y)
end

function ps_set_frequency(e, frequency)
 e.frequency = frequency
end

function ps_set_max_p(e, max_p)
 e.max_p = max_p
end

function ps_set_gravity(e, gravity)
 e.gravity = gravity
end

function ps_set_burst(e, burst, burst_amount)
 e.burst = burst
 e.burst_amount = burst_amount or e.max_p
end

function ps_set_pooling(e, pooling)
 e.use_pooling = pooling
 e.pool = {}
 if (e.use_pooling and e.max_p < 1) then
  e.max_p = 20
 end
end

function ps_set_rnd_colour(e, rnd_colour)
 e.rnd_colour = rnd_colour
end

function ps_set_rnd_sprite(e, rnd_sprite)
 e.rnd_sprite = rnd_sprite
end

function ps_set_area(e, width, height)
 e.use_area = width ~= nil and height ~= nil and (width > 0 or height > 0)
 e.area_width = width or 0
 e.area_height = height or 0
end

function ps_set_colours(e, colours)
 e.p_colours = colours
end

function ps_set_sprites(e, sprites)
 e.p_sprites = sprites
end

function ps_set_life(e, life, life_spread)
 e.p_life = life
 e.p_life_spread = life_spread or 0
end

function ps_set_angle(e, angle, angle_spread)
 e.p_angle = angle
 e.p_angle_spread = angle_spread or 0
end

function ps_set_speed(e, speed_initial, speed_final, speed_spread_initial, speed_spread_final)
 e.p_speed_initial = speed_initial
 e.p_speed_final = speed_final or speed_initial
 e.p_speed_spread_initial = speed_spread_initial or 0
 e.p_speed_spread_final = speed_spread_final or e.p_speed_spread_initial
end

function ps_set_size(e, size_initial, size_final, size_spread_initial, size_spread_final)
 e.p_size_initial = size_initial
 e.p_size_final = size_final or size_initial
 e.p_size_spread_initial = size_spread_initial or 0
 e.p_size_spread_final = size_spread_final or e.p_size_spread_initial
end
