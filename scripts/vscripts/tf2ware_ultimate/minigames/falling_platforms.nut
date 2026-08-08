minigame <- Ware_MinigameData
({
	name           = "Falling Platforms"
	author         = ["TonyBaretta", "ficool2"]
	description    = "Push away the enemies!"
	duration       = 87.0
	end_delay      = 1.0
	location       = "hexplatforms"
	music          = "falling"
	custom_overlay = "push_enemy"
	min_players    = 2	
	start_pass     = true
	start_freeze   = 0.5
	fail_on_death  = true
	allow_damage   = true
	collisions     = true
	convars =
	{
		tf_avoidteammates = 0
	}
})

// https://www.redblobgames.com/grids/hexagons/implementation.html
class Hex
{
	function constructor(_q, _r)
	{
		q = _q
		r = _r
		s = -_q - _r
	}
	
	function _cmp(h) { return q == h.q && r == h.r && s == h.s }
	function _add(h) { return Hex(q + h.q, r + h.r, s + h.s) }
	function _sub(h) { return Hex(q - h.q, r - h.r, s - h.s) }
	function _mul(h) { return Hex(q * h.q, r * h.r, s * h.s) }
	
	function ToScreenspace()
	{
		return Vector2D
		(
			1.73205 * q + 0.866025 * r,
			1.5 * r
		)
	}
	
	function Spawn(origin, size, model, speed)
	{
		local screen = ToScreenspace()
		local position = origin + Vector(screen.x * size, screen.y * size)
		
		entity = Ware_SpawnEntity("func_door",
		{
			origin         = position
			model          = model
			movedir        = "90 0 0"
			speed          = speed
			wait           = -1.0
			forceclosed    = true
			ignoredebris   = true
			disableshadows = true
			disablereceiveshadows = true
		})
		entity.AddFlag(FL_UNBLOCKABLE_BY_PLAYER)
		SetPropInt(entity, "m_takedamage", DAMAGE_YES)
	}
	
	q = null
	r = null
	s = null
	entity = null
}

hexes <- []
lower_delay <- 5.0

function OnStart()
{
	Ware_SetGlobalLoadout(TF_CLASS_SPY)
	Ware_ChatPrint(null, "{color}TIP{color}: Wall climb by hitting the wall!", COLOR_LIME, TF_COLOR_DEFAULT)	
}

function OnTeleport(players)
{
	local center = Ware_MinigameLocation.center * 1.0
	local models = Ware_MinigameLocation.plat_models
	
	local min_z = -128.0, max_z = 32.0
	local size = 112.0
	local speed = 300.0

	local shape = RandomInt(0, 3)
	local len = players.len()
	local dim = Max(ceil(sqrt(len)).tointeger() + 1, 4)
	
	local function SpawnHex(q, r)
	{
		local hex = Hex(q, r)
		local pos = center * 1.0
		pos.z += Round(RandomFloat(min_z, max_z))
		hex.Spawn(pos, size, RandomElement(models), speed)
		hexes.append(hex)
	}
	
	// HACK
	if (shape == 0)	
		center -= Vector(1400, 1400, 0)	
	else if (shape == 1)	
		center -= Vector(1200, 1200, 0)	
	else if (shape == 3)
		center -= Vector(1000, 1000, 0)
	
	if (shape == 0) // parallelogram
	{
		for (local q = 0; q < dim; q++)
		{
			for (local r = 0; r < dim; r++) 
			{
				SpawnHex(q, r)
			}
		}
	}
	else if (shape == 1) // triangle
	{
		// hack: this is not really right
		if (len >= 16) dim++
		if (len >= 46) dim++		
		if (len >= 79) dim++
		for (local q = 0; q < dim; q++) 
		{
			for (local r = 0; r < dim - q; r++) 
			{
				SpawnHex(q, r)
			}
		}	
	}
	else if (shape == 2) // hexagon
	{
		// this is also not really right
		dim = Min(dim - 1, 6)
		local count = 0
		for (local q = -dim; q < dim; q++) 
		{
			local r1 = Max(-dim, -q - dim)
			local r2 = Min( dim, -q + dim)
			for (local r = r1; r < r2; r++)
			{
				SpawnHex(q, r)
			}
		}	
	}
	else if (shape == 3) // rectangle
	{
		local left = 0, right = dim
		local top = 0, bottom = dim
		
		for (local r = top; r < bottom; r++) 
		{
			local r_offset = r >> 1
			for (local q = left - r_offset; q < right - r_offset; q++) 
			{
				SpawnHex(q, r)
			}
		}	
	}
	
	Shuffle(hexes)
	
	lower_delay = (minigame.duration - 17.0) / hexes.len().tofloat()
	Ware_CreateTimer(@() LowerPlatform(), 10.0)
	
	local hex_len = hexes.len()
	local hex_idx = 0
	foreach (player in players)
	{
		local origin = hexes[hex_idx].entity.GetOrigin()
		origin.z += 900.0
		hex_idx = (hex_idx + 1) % hex_len

		local dir = center - origin
		dir.z = 0.0
		dir.Norm()
		Ware_TeleportPlayer(player, origin, VectorAngles(dir), vec3_zero)		
	}
}

function LowerPlatform()
{
	local hex = RemoveRandomElement(hexes)
	
	EntityEntFire(hex.entity, "Color", "255 50 50", 0.0)
	EntityEntFire(hex.entity, "Color", "255 255 255", 0.5)
	EntityEntFire(hex.entity, "Color", "255 50 50", 1.0)
	EntityEntFire(hex.entity, "Color", "255 255 255", 1.5)
	EntityEntFire(hex.entity, "Color", "255 50 50", 2.0)
	EntityEntFire(hex.entity, "Color", "255 255 255", 2.5)
	EntityEntFire(hex.entity, "Open", "", 2.5)
	
	if (hexes.len() > 1)
		return lower_delay
}

function OnTakeDamage(params)
{
	local victim = params.const_entity
	local attacker = params.attacker
		
	if (victim.IsPlayer())
	{
		if (attacker && attacker.IsPlayer())
		{
			local dir = attacker.EyeAngles().Forward()
			local vel = victim.GetAbsVelocity()
			dir.z = Max(dir.z, 0.0)
			vel += dir * 300.0 * (Min(params.damage, 100.0) / 40.0)
			vel.z += 450.0
			victim.SetAbsVelocity(vel)
			params.damage = 1.0
		}
	}
	else if (victim.GetClassname() == "func_door")
	{
		if (attacker && attacker.IsPlayer())
		{
			local vel = attacker.GetAbsVelocity()
			vel.z = Max(vel.z, 450.0)
			attacker.SetAbsVelocity(vel)
		}
		
		return false
	}
}

function OnCheckEnd()
{
	return Ware_GetAlivePlayers().len() <= 1
}