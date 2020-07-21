---------------------------
--        pico-ps        --
--    particle system    --
--  author: max kearney  --
--  created: april 2019  --
--  updated: july 2020   --
---------------------------

-- this version has no documentation! please see ps.lua for the docs.

-- globals
prev_time = nil
delta_time = nil

function update_time()
 delta_time = time()-prev_time
 prev_time = time()
end

gravity = 50

function calc_gravity(a)
 a.velocity.y = a.velocity.y + delta_time * gravity
end

-- point2d
point2d = {}
point2d.__index = point2d
function point2d.create(x,y)
 local p = {}
 setmetatable (p, point2d)
 p.x = x
 p.y = y
 return p
end

-- particle
particle = {}
particle.__index = particle
function particle.create(x, y, gravity, colour, sprite, life, angle, speed_initial, speed_final, size_initial, size_final)
 local p = {}
 setmetatable (p, particle)

 p.pos = point2d.create(x,y)
 p.colour = colour
 p.life_initial = life
 p.life = life

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

function particle:update(dt)
 self.life = self.life - dt

 if (self.gravity) then
  calc_gravity(self)
 end

 if (self.size_initial ~= self.size_final) then
  self.size = self.size - ((self.size_initial-self.size_final)/self.life_initial)*dt
 end

 if (self.vel_initial.x ~= self.vel_final.x) then
  self.velocity.x = self.velocity.x - ((self.vel_initial.x-self.vel_final.x)/self.life_initial)*dt
  self.velocity.y = self.velocity.y - ((self.vel_initial.y-self.vel_final.y)/self.life_initial)*dt
 end

 if (self.life > 0) then
  self.pos.x = self.pos.x + self.velocity.x * dt
  self.pos.y = self.pos.y + self.velocity.y * dt
 else
  self.die(self)
 end
end

function particle:draw()
 if (self.sprite ~= nil) then
  spr(self.sprite, self.pos.x, self.pos.y)
 else
  circfill(self.pos.x, self.pos.y, self.size, self.colour)
 end
end

function particle:die()
 self.dead = true
end

-- particle emitter
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

 p.pos = point2d.create(x,y)
 p.emitting = true
 p.frequency = frequency
 p.emit_time = frequency
 p.max_p = max_p
 p.gravity = gravity or false
 p.burst = burst or false
 p.rnd_colour = rnd_colour or false

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

function emitter:get_new_particle()
 local sprite = nil
 if (self.p_sprites ~= nil) then sprite = self.p_sprites[flr(rnd(#self.p_sprites))+1] end

 local speed_spread = rnd(self.p_speed_spread)
 local size_spread = rnd(self.p_size_spread)

 local p = particle.create
 (
  self.pos.x, self.pos.y,
  self.gravity,
  self.get_colour(self), sprite,
  self.p_life + rnd(self.p_life_spread),
  self.p_angle + rnd(self.p_angle_spread),
  self.p_speed_initial + speed_spread, self.p_speed_final + speed_spread,
  self.p_size_initial + size_spread, self.p_size_final + size_spread 
 )
 return p
end

function emitter:emit(dt)
 if (self.emitting) then
  if (self.burst) then
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