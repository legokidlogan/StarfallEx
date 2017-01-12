---------------------------------------------------------------------
-- SF Permissions management
---------------------------------------------------------------------

SF.Permissions = {}

local P = SF.Permissions
P.providers = {}

--- Adds a provider implementation to the set used by this library.
-- Providers must implement the {@link SF.Permissions.Provider} interface.
-- @param provider the provider to be registered
function P.registerProvider ( provider )
	P.providers[ #P.providers + 1 ] = provider
end

--- Registers a privilege
-- @param id unique identifier of the privilege being registered
-- @param name Human readable name of the privilege
-- @param description a short description of the privilege
function P.registerPrivilege ( id, name, description, arg )
	for _, provider in ipairs( P.providers ) do
		provider.registered( id, name, description, arg )
	end
end

--- Checks whether a player may perform an action.
-- @param principal the player performing the action to be authorized
-- @param target the object on which the action is being performed
-- @param key a string identifying the action being performed
-- @return boolean whether the action is permitted
function P.check ( principal, target, key )

	for _, provider in ipairs( P.providers ) do
		local setting = provider.settings[ key ]
		if setting then
			local check = provider.checks[ setting ]
			if check then
				if not check( principal, target, key ) then
					SF.throw( "Insufficient permissions: " .. key, 3 )
				end
			else
				SF.throw( "'" .. provider.id .. "' bad setting for permission " .. key .. ": " .. setting, 3 )
			end
		end
	end

end

function P.hasAccess ( principal, target, key )

	for _, provider in ipairs( P.providers ) do
		local setting = provider.settings[ key ]
		if setting then
			local check = provider.checks[ setting ]
			if check then
				if not check( principal, target, key ) then return false end
			else
				SF.throw( "'" .. provider.id .. "' bad setting for permission " .. key .. ": " .. setting, 3 )
			end
		end
	end
	
	return true
end

function P.savePermissions()
	local settings = {}
	for _, provider in ipairs( P.providers ) do
		if next(provider.settings) then
			local tbl = {}
			for k, v in pairs(provider.settings) do
				tbl[k] = v
			end
			settings[ provider.id ] = tbl
		end
	end
	file.Write( "sf_perms.txt", util.TableToJSON( settings ) )
end

-- Find and include all provider files.
do
	local function IncludeClientFile ( file )
		if SERVER then
			AddCSLuaFile( file )
		else
			include( file )
		end
	end

	if SERVER then
		local files = file.Find( "starfall/permissions/providers_sv/*.lua", "LUA" )

		for _, file in pairs( files ) do
			include( "starfall/permissions/providers_sv/" .. file )
		end
	end

	local sh_files = file.Find( "starfall/permissions/providers_sh/*.lua", "LUA" )

	for _, file in pairs( sh_files ) do
		if SERVER then
			AddCSLuaFile( "starfall/permissions/providers_sh/" .. file )
		end
		include( "starfall/permissions/providers_sh/" .. file )
	end

	local cl_files = file.Find( "starfall/permissions/providers_cl/*.lua", "LUA" )

	for _, file in pairs( cl_files ) do
		IncludeClientFile( "starfall/permissions/providers_cl/" .. file )
	end
end

-- Load the permission settings for each provider
local settings = util.JSONToTable( file.Read( "sf_perms.txt" ) or "" )
for _, provider in ipairs( P.providers ) do
	if settings[ provider.id ] then
		for k, v in pairs(settings[provider.id]) do
			provider.settings[k] = v
		end
	end
end

local function changePermission( ply, arg )
	local provider
	for _, p in ipairs(P.providers) do if p.id == arg[1] then provider = p break end end
	if provider then
		if arg[2] and provider.settings[arg[2]] then
			local val = tonumber(arg[3])
			if val and val>=1 and val<=#provider.settingsoptions then
				provider.settings[arg[2]] = math.floor( val )
				P.savePermissions()
			else
				ply:PrintMessage( HUD_PRINTCONSOLE, "The setting's value is out of bounds or not a number." )
			end
		else
			local settings = {}
			for id, _ in SortedPairs(P.providers) do settings[#settings+1]=id end
			ply:PrintMessage( HUD_PRINTCONSOLE, "Setting, " .. tostring(arg[2]) .. ", couldn't be found.\nHere's a list of settings.\n" .. table.concat(settings, "\n") )
		end
	else
		local providers = {}
		for _, p in ipairs(P.providers) do providers[_]=p.id end
		ply:PrintMessage( HUD_PRINTCONSOLE, "Permission provider, " .. tostring(arg[1]) .. ", couldn't be found.\nHere's a list of providers.\n" .. table.concat(providers, "\n") )
	end
end

-- Console commands for changing permissions.
if SERVER then
	concommand.Add("sf_permission", function(ply, com, arg)
		if ply:IsValid() and not ply:IsSuperAdmin() then return end
		changePermission(ply, arg)
	end)
else
	concommand.Add("sf_permission_cl", function(ply,com,arg)
		changePermission(ply, arg)
	end)
end
