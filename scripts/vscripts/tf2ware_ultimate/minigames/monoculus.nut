minigame <- Ware_MinigameData
({
	name           = "Survive MONOCULUS"
	author         = ["TonyBaretta", "ficool2"]
	description    = "Survive!"
	duration       = 40.0
	end_delay      = 1.0
	music          = "monoculus"
	custom_overlay = "survive"
	start_pass     = true
	fail_on_death  = true
	allow_damage   = true
	convars        =
	{
		tf_flamethrower_burstammo = 0
	}
})

monoculuses <- []
offset <- Vector(0, 0, 256)

function OnPrecache()
{
	PrecacheEntityFromTable({classname = "eyeball_boss"})
}

function OnStart()
{
	Ware_SetGlobalLoadout(TF_CLASS_PYRO, "Flame Thrower")
	
	Ware_CreateTimer(@() SpawnMonoculus(), 0.1)
	Ware_CreateTimer(@() SpawnMonoculus(), 3.0)

	if (Ware_MinigameLocation.name.find("big") != null)
	{
		Ware_CreateTimer(@() SpawnMonoculus(), 1.4)
		Ware_CreateTimer(@() SpawnSkeletonKing(), 1.5)
	}
}

function SpawnMonoculus()
{
	local monoculus = Ware_SpawnEntity("eyeball_boss",
	{
		origin  = Ware_MinigameLocation.center + offset
		teamnum = 5
	})
	monoculus.ValidateScriptScope()
	monoculus.GetScriptScope().MonoculusThink <- function()
	{
		// makes the monoculus not look jittery
		self.FlagForUpdate(true)
		return 0.05
	}
	AddThinkToEnt(monoculus, "MonoculusThink")	
	offset.x += 128.0
	offset.z += 256.0
	monoculuses.append(monoculus)
}

function SpawnSkeletonKing()
{
	local skeleton_spawner = Ware_SpawnEntity("tf_zombie_spawner",
	{
		origin          = Ware_MinigameLocation.center + Vector(0, 0, 64)
		zombie_lifetime = Ware_GetMinigameRemainingTime()
		zombie_type     = 1
		max_zombies     = 1		
	})
	skeleton_spawner.AcceptInput("Enable", "", null, null)
	Ware_CreateTimer(function()
	{
		for (local skeleton; skeleton = FindByClassname(skeleton, "tf_zombie");)
		{
			skeleton.ValidateScriptScope()
			skeleton.GetScriptScope().SkeletonThink <- function()
			{
				// makes the skeleton not look jittery
				self.FlagForUpdate(true)
				return 0.05
			}
			AddThinkToEnt(skeleton, "SkeletonThink")
		}
	}, 0.1)
}

function OnUpdate()
{
	monoculuses = monoculuses.filter(@(i, monoculus) monoculus.IsValid())
	
	// fix them getting stuck inside of each other
	foreach (monoculus in monoculuses)
	{
		foreach (other_monoculus in monoculuses)
		{
			if (monoculus == other_monoculus)
				continue
				
			if (VectorDistance(monoculus.GetOrigin(), other_monoculus.GetOrigin()) < 128.0)
			{
				local dest = monoculus.GetOrigin() + 
						Vector(RandomBool() ? 256.0 : -256.0, RandomBool() ? 256.0 : -256.0, 0.0)
				monoculus.Teleport(true, dest, false, QAngle(), true, Vector())
				break
			}
		}
	}
	
	// disable primary fire
	foreach (player in Ware_MinigamePlayers)
	{
		local weapon = player.GetActiveWeapon()
		if (weapon && weapon.GetSlot() == TF_SLOT_PRIMARY)
			SetPropFloat(weapon, "m_flNextPrimaryAttack", 1e30)
	}
}

function OnCleanup()
{
	local event_send = Ware_GetAlivePlayers().len() > 0
	foreach (monoculus in monoculuses)
	{
		if (monoculus.IsValid())
		{
			if (event_send)
			{
				SendGlobalGameEvent("eyeball_boss_killed", {})
				event_send = false
			}
			monoculus.Kill()
		}
	}
	
	local skeletons = []
	for (local skeleton; skeleton = FindByClassname(skeleton, "tf_zombie");)
		skeletons.append(skeleton)
	foreach (skeleton in skeletons)
		skeleton.Kill() // TODO TakeDamage doesn't work
}

function OnCheckEnd()
{
	return Ware_GetAlivePlayers().len() == 0
}