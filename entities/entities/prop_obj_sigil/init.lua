AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:DrawShadow(false)

	self:SetModel("models/d3/other/concrete_obelisc/concrete_obelisc.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:EnableMotion(false)
		phys:Wake()
	end

	self:SetSigilHealthBase(self.MaxHealth)
	self:SetSigilHealthRegen(self.HealthRegen)
	self:SetSigilLastDamaged(0)
end

function ENT:Think()
	if self.TeleportingENT then
		if self.TeleportingENT.SigilPowerUpDelay ~= nil and self.TeleportingENT.SigilPowerUpDelay <= CurTime() then
			self:TeleportPlayer(self.TeleportingENT)
			self.TeleportingENT.SigilPowerUpDelay = nil
		end
	end
end

function ENT:Use(activator, caller)
	if caller.SigilCoolDown <= CurTime() then
		self.TeleportingID = caller:UniqueID()
		self.TeleportingENT = caller
		caller.SigilCoolDown = CurTime() + 5
		caller.SigilPowerUpDelay = CurTime() + 5
	end
end

local function SigilTeleport(caller, currentsigil, index, first)
	local sigils = ents.FindByClass("prop_obj_sigil")
	local sigil = sigils[index]
	
	--If there is a better method of doing this then please replace this part!
	--This is just here for now to prevent instant teleporting!
	--TODO: Make a progress bar which will probably be in status_sigilteleport?
	--TODO: Area of teleport, if player isnt close to sigil the time restarts.
	--DONE: Also use CurTime() instead!
	
	caller:ChatPrint(translate.Get("sigil_teleporting"))
	caller:SetPos(sigil:GetPos())
	
	caller:SetBarricadeGhosting(true)
	currentsigil:EmitSound("friends/message.wav")
	
	if first == true then
		sigil:EmitSound("friends/friend_join.wav")
			caller:SendLua("surface.PlaySound('friends/friend_join.wav')")
	else
		sigil:EmitSound("friends/friend_online.wav")
		caller:SendLua("surface.PlaySound('friends/friend_online.wav')")
	end
end

function ENT:TeleportPlayer(caller)
	local currentSigil = self:GetSigilLetter()
	local sigils = ents.FindByClass("prop_obj_sigil")

	if IsValid(caller) and caller:IsPlayer() then
		if caller:Team() ~= TEAM_UNDEAD then
			--It is better to use a pair loop rather than trying to find all the sigil letters
			for _, ent in pairs(sigils) do
				local sigilIndex = 0
				local nextSigilIndex = 0
				if currentSigil == ent:GetSigilLetter() then
					sigilIndex = _
					nextSigilIndex = sigilIndex + 1
				end
				if sigils[nextSigilIndex] ~= nil then
						SigilTeleport(caller, self, nextSigilIndex, false)
				else
					if nextSigilIndex ~= 0 then
						SigilTeleport(caller, self, 1, true)
					end
				end
			end
		end
	end
end

function ENT:OnTakeDamage(dmginfo)
	if self:GetSigilHealth() <= 0 then return end

	local attacker = dmginfo:GetAttacker()
	if not (attacker:IsValid() and attacker:IsPlayer() and attacker:Team() == TEAM_UNDEAD and dmginfo:GetDamage() > 2) then return end

	local oldhealth = self:GetSigilHealth()
	self:SetSigilLastDamaged(CurTime())
	self:SetSigilHealthBase(oldhealth - dmginfo:GetDamage())

	if self:GetSigilHealth() <= 0 then
		self:SetSigilHealthBase(0)

		gamemode.Call("OnSigilDestroyed", self, dmginfo)

		self:Destroy()
	end
end

function ENT:Destroy()
	local effectdata = EffectData()
	effectdata:SetOrigin(self:LocalToWorld(self:OBBCenter()))
	util.Effect("Explosion", effectdata, true, true)

	self:Fire("kill", "", 0.01)
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end