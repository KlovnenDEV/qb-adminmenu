local ACTIVE = false
local buttonsScaleform
local PENDING = false
local cam
local MODE = 1
local ZERO = vector3(0,0,0)
local SPEED = 5
local camType = 0

Config = {
	BoostFactor = 10.0,
	Sensitivity = 5.0,
	Conceal = false,
	Speed = {
		Min = 5,
		Start = 10,
		Max = 100,
		Interval = 5,
	},
	UseModifier = false,
	Keys = {
		Modifier = 21, -- INPUT_SPRINT, Left Shift
		Boost = 21, -- INPUT_SPRINT, Left Shift
		Teleport = 37, -- INPUT_SELECT_WEAPON, Tab
		SlowDown = 44, -- INPUT_COVER, Q
		SpeedUp = 38, -- INPUT_PICKUP, E
		SwitchMode = 25, -- INPUT_AIM, right click
		Forward = 32, -- W
		Back = 33, -- S
		Left = 34, -- A
		Right = 35, -- D
		Up = 22, -- INPUT_JUMP, Space
		Down = 36, -- INPUT_DUCK
	},
}

Citizen.CreateThread(function()
	camType = GetResourceKvpInt('camera_type') or 0
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		stopCam()
	end
end)

AddTextEntry('DCAMTARGETOBJECT','Model: ~a~~n~XYZ: ~a~~n~Heading: ~a~')
AddTextEntry('DCAMMODE', 'FreeCam Mode ~1~/~1~~n~~a~~n~SPEED: ~1~%')

AddEventHandler('rpuk_admin:setCameraType', function(_camType)
	SetResourceKvpInt('camera_type', _camType)
	camType = _camType
end)

function saveToFile(info)
	TriggerServerEvent('qb-admin:server:printData', info)
end

function getCam()
	if not cam or not DoesCamExist(cam) then
		cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	end
	return cam
end

function startCam()
	PENDING = false
	if not ACTIVE then

		local location = GetGameplayCamCoord()
		local rot = GetGameplayCamRot(2)
		local fov = GetGameplayCamFov()

		local cam = getCam()
		RenderScriptCams(true, true, 500, true, false, false)
		buttonsScaleform = ScaleformSC('instructional_buttons')
		SetCamCoord(cam, location)
		SetCamRot(cam, rot, 2)
		SetCamFov(cam, fov)
		ACTIVE = true
	end
end

ScaleformSC = function(movie)
	local scaleform = RequestScaleformMovie(movie)
	while not HasScaleformMovieLoaded(scaleform) do Citizen.Wait(100) end

	return scaleform
end

function stopCam(teleport)
	if ACTIVE then
		local player = PlayerId()
		if NetworkIsPlayerConcealed(player) then
			NetworkConcealPlayer(player, false, false)
		end

		if teleport then
			RenderScriptCams(false, false, 0, false, false, false)
		else
			local time = math.floor(#( GetCamCoord(cam) - GetEntityCoords(PlayerPedId())))
			RenderScriptCams(false, true, time, false, false, false)
		end
		DestroyCam(getCam(), false)
		cam = nil

		ClearFocus()
		NetworkClearVoiceProximityOverride()
		SetScaleformMovieAsNoLongerNeeded(buttonsScaleform)
	end
	ACTIVE = false
end

function disableFuckingEverything()
	for i=0, 31 do
		DisableAllControlActions(i)
	end
end

function getMouseMovement()
	local x = GetDisabledControlNormal(0, 2)
	local y = 0
	local z = GetDisabledControlNormal(0, 1)
	return vector3(-x, y, -z) * 5
end

function getRelativeLocation(location, rotation, distance)
	location = location or vector3(0,0,0)
	rotation = rotation or vector3(0,0,0)
	distance = distance or 10.0

	local tZ = math.rad(rotation.z)
	local tX = math.rad(rotation.x)

	local absX = math.abs(math.cos(tX))

	local rx = location.x + (-math.sin(tZ) * absX) * distance
	local ry = location.y + (math.cos(tZ) * absX) * distance
	local rz = location.z + (math.sin(tX)) * distance

	return vector3(rx,ry,rz)
end

function getMovementInput(location, rotation, frameTime)
	local multiplier = 1.0

	if IsDisabledControlJustPressed(0, Config.Keys.SpeedUp) then
		SPEED = SPEED + Config.Speed.Interval
		SPEED = math.min(SPEED, Config.Speed.Max)
	elseif IsDisabledControlJustPressed(0, Config.Keys.SlowDown) then
		SPEED = SPEED - Config.Speed.Interval
		SPEED = math.max(SPEED, Config.Speed.Min)
	end

	if IsDisabledControlPressed(0, Config.Keys.Boost) then
		multiplier = Config.BoostFactor
	end

	local speed = SPEED * frameTime * multiplier

	if IsDisabledControlPressed(0, Config.Keys.Right) then
		local camRot = vector3(0,0,rotation.z)
		location = getRelativeLocation(location, camRot + vector3(0,0,-90), speed)
	elseif IsDisabledControlPressed(0, Config.Keys.Left) then
		local camRot = vector3(0,0,rotation.z)
		location = getRelativeLocation(location, camRot + vector3(0,0,90), speed)
	end

	if IsDisabledControlPressed(0, Config.Keys.Forward) then
		location = getRelativeLocation(location, rotation, speed)
	elseif IsDisabledControlPressed(0, Config.Keys.Back) then
		location = getRelativeLocation(location, rotation, -speed)
	end

	if IsDisabledControlPressed(0, Config.Keys.Up) then
		location = location + vector3(0,0,speed)
	elseif IsDisabledControlPressed(0, Config.Keys.Down) then
		location = location + vector3(0,0,-speed)
	end

	return location
end

function drawEntityBox(entity,r,g,b,a)
	if entity then

		r = r or 255
		g = g or 0
		b = b or 0
		a = a or 40

		local model = GetEntityModel(entity)
		local min,max = GetModelDimensions(model)

		local top_front_right = GetOffsetFromEntityInWorldCoords(entity,max)
		local top_back_right = GetOffsetFromEntityInWorldCoords(entity,vector3(max.x,min.y,max.z))
		local bottom_front_right = GetOffsetFromEntityInWorldCoords(entity,vector3(max.x,max.y,min.z))
		local bottom_back_right = GetOffsetFromEntityInWorldCoords(entity,vector3(max.x,min.y,min.z))

		local top_front_left = GetOffsetFromEntityInWorldCoords(entity,vector3(min.x,max.y,max.z))
		local top_back_left = GetOffsetFromEntityInWorldCoords(entity,vector3(min.x,min.y,max.z))
		local bottom_front_left = GetOffsetFromEntityInWorldCoords(entity,vector3(min.x,max.y,min.z))
		local bottom_back_left = GetOffsetFromEntityInWorldCoords(entity,min)


		-- LINES

		-- RIGHT SIDE
		DrawLine(top_front_right,top_back_right,r,g,b,a)
		DrawLine(top_front_right,bottom_front_right,r,g,b,a)
		DrawLine(bottom_front_right,bottom_back_right,r,g,b,a)
		DrawLine(top_back_right,bottom_back_right,r,g,b,a)

		-- LEFT SIDE
		DrawLine(top_front_left,top_back_left,r,g,b,a)
		DrawLine(top_back_left,bottom_back_left,r,g,b,a)
		DrawLine(top_front_left,bottom_front_left,r,g,b,a)
		DrawLine(bottom_front_left,bottom_back_left,r,g,b,a)

		-- Connection
		DrawLine(top_front_right,top_front_left,r,g,b,a)
		DrawLine(top_back_right,top_back_left,r,g,b,a)
		DrawLine(bottom_front_left,bottom_front_right,r,g,b,a)
		DrawLine(bottom_back_left,bottom_back_right,r,g,b,a)


		-- POLYGONS

		-- FRONT
		DrawPoly(top_front_left,top_front_right,bottom_front_right,r,g,b,a)
		DrawPoly(bottom_front_right,bottom_front_left,top_front_left,r,g,b,a)

		-- TOP
		DrawPoly(top_front_right,top_front_left,top_back_right,r,g,b,a)
		DrawPoly(top_front_left,top_back_left,top_back_right,r,g,b,a)

		-- BACK
		DrawPoly(top_back_right,top_back_left,bottom_back_right,r,g,b,a)
		DrawPoly(top_back_left,bottom_back_left,bottom_back_right,r,g,b,a)

		-- LEFT
		DrawPoly(top_back_left,top_front_left,bottom_front_left,r,g,b,a)
		DrawPoly(bottom_front_left,bottom_back_left,top_back_left,r,g,b,a)

		-- RIGHT
		DrawPoly(top_front_right,top_back_right,bottom_front_right,r,g,b,a)
		DrawPoly(top_back_right,bottom_back_right,bottom_front_right,r,g,b,a)

		-- BOTTOM
		DrawPoly(bottom_front_left,bottom_front_right,bottom_back_right,r,g,b,a)
		DrawPoly(bottom_back_right,bottom_back_left,bottom_front_left,r,g,b,a)

		return true

	end
	return false
end

function drawEntityInfo(entity, textLocation, networked)
	local heading = GetEntityHeading(entity)
	local model = GetEntityModel(entity)
	local location = GetEntityCoords(entity)

	SetDrawOrigin(textLocation, false)
	if networked then
		BeginTextCommandDisplayText("DCAMTARGETOBJECTNET")
	else
		BeginTextCommandDisplayText("DCAMTARGETOBJECT")
	end
	SetTextScale(0.3,0.3)
	SetTextOutline()
	AddTextComponentSubstringPlayerName(model)
	AddTextComponentSubstringPlayerName(string.format("vector3(%.2f, %.2f, %.2f)", location.x, location.y, location.z))
	AddTextComponentSubstringPlayerName(string.format("%.2f", heading))

	if networked then
		local owner = NetworkGetEntityOwner(entity)
		local name = GetPlayerName(owner):gsub("%W", " ")
		AddTextComponentInteger(GetPlayerServerId(owner))
		AddTextComponentSubstringPlayerName(name)
	end
	EndTextCommandDisplayText(0.0, 0.0)
	ClearDrawOrigin()
	return model
end

local MODES = {
	{
		name = '📍 Teleport',
		marker = {
			type = 28,
			offset = vector3(0,0,0),
			scale = 0.1,
			color = {255, 255, 255, 150},
		},
		entityBox = false,
		rayFlags = 23,
		click = function(location, heading, entity, networked)
			local spec = string.format("coords=vector3(%.3f, %.3f, %.3f)\nheading=%.3f\n", location.x, location.y, location.z, heading)
			saveToFile(spec)
			RequestCollisionAtCoord(121.3, location.x, location.y, location.z)
			if IsPedInAnyVehicle(PlayerPedId(), 0) and (GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId(), 0), -1) == PlayerPedId()) then
				SetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), 0), location.x, location.y, location.z)
			else
				SetEntityCoords(PlayerPedId(), location.x, location.y, location.z)
			end
			entity = PlayerPedId()
		end,
	},
	{
		name = '', -- no marker
		marker = {
			type = -1,
			offset = vector3(0,0,0),
			scale = 0.1,
			color = {255, 255, 255, 150},
		},
		entityBox = false,
		rayFlags = 23,
		click = function(location, heading, entity, networked)
			local spec = string.format("coords=vector3(%.3f, %.3f, %.3f)\nheading=%.3f\n", location.x, location.y, location.z, heading)
			saveToFile(spec)
		end,
	},
	{
		name = '📍 '..Lang:t("menu.coordinate_finder"),
		marker = {
			type = 28,
			offset = vector3(0,0,0),
			scale = 0.1,
			color = {255, 255, 255, 200},
		},
		entityBox = false,
		rayFlags = 23,
		click = function(location, heading, entity, networked)
			local spec = string.format("vector3(%.1f, %.1f, %.1f),\n", location.x, location.y, location.z)
			saveToFile(spec)
		end,
	},
	{
		name = '📍 '..Lang:t("menu.xy_printer"),
		marker = {
			type = 1,
			offset = vector3(0,0,0),
			scale = 1.0,
			color = {255, 255, 255, 200},
		},
		entityBox = false,
		rayFlags = 23,
		click = function(location, heading, entity, networked)
			local spec = string.format("vector2(%.1f, %.1f),\n", location.x, location.y)
			saveToFile(spec)
		end,
	},
	{
		name = '🚪 '..Lang:t("menu.object_finder"),
		marker = {
			type = 0,
			offset = vector3(0,0,0),
			scale = 0.3,
			color = {255, 255, 255, 150},
		},
		entityBox = true,
		rayFlags = 17,
		click = function(location, heading, entity, networked)
			if entity then
				local heading = GetEntityHeading(entity)
				local model = GetEntityModel(entity)
				local location = GetEntityCoords(entity)
				local spec = string.format("hash = %i\ncoords = vector3(%.3f, %.3f, %.3f)\nstate = {pitch = 0.0, roll = -0.0,yaw = %.3f}\n", model, location.x, location.y, location.z, heading)
				saveToFile(spec)
			end
		end,
	},
	--
	--[[
	{
		name = '🚪 '..Lang:t("menu.of_printer"),
		marker = {
			type = -1,
			offset = vector3(0,0,0),
			scale = 0.3,
			color = {255, 255, 255, 150},
		},
		entityBox = true,
		rayFlags = 17,
		click = function(location, heading, entity, networked)
			local playerPed = PlayerPedId()
			local pedModel = GetEntityModel(playerPed)

			local pants,pantst = GetPedDrawableVariation(playerPed,4),GetPedTextureVariation(playerPed,4)  		-- Pants
			local arms,armst = GetPedDrawableVariation(playerPed,3),GetPedTextureVariation(playerPed,3) 		-- Arms
			local shirt,shirtt = GetPedDrawableVariation(playerPed,8),GetPedTextureVariation(playerPed,8)		-- T-Shirt
			local vest,vestt = GetPedDrawableVariation(playerPed,9),GetPedTextureVariation(playerPed,9)			-- Vest
			local torso,torsot = GetPedDrawableVariation(playerPed,11),GetPedTextureVariation(playerPed,11) 	-- Torso2
			local shoes,shoest = GetPedDrawableVariation(playerPed,6),GetPedTextureVariation(playerPed,6)		-- Shoes
			local acc,acct = GetPedDrawableVariation(playerPed,7),GetPedTextureVariation(playerPed,7)			-- access9ry
			local bag,bagt = GetPedDrawableVariation(playerPed,5),GetPedTextureVariation(playerPed,5)			-- Bag
			local hat,hatt = GetPedPropIndex(playerPed,0),GetPedPropTextureIndex(playerPed,0)					-- Head
			local glass,glasst = GetPedPropIndex(playerPed,1),GetPedPropTextureIndex(playerPed,1)				-- Glass - Eye
			local mask,maskt = GetPedDrawableVariation(playerPed,1),GetPedTextureVariation(playerPed,1)			-- Maske
			local ear,eart = GetPedPropIndex(playerPed,2),GetPedPropTextureIndex(playerPed,2)					-- Eye Acc.


			table = nil
			Citizen.Wait(5)

			--table = string.format("['%s'] = {\n[0] = {'prop',%s,0},\n[3] = {'comp',%s},\n[4] = {'comp',%s},\n[5] = {'comp',%s},\n[6] = {'comp',%s},\n[8] = {'comp',%s},\n[11] = {'comp',%s}\n},\n\n",playerSex,head,torso,legs,hands,shoes,undershirt,tops)
			table =
			string.format(
				'-------------------------------------------------\noutfitData = {\n	["pants"] = {item = %s, texture = %s},\n	["arms"] = {item = %s, texture = %s},\n	["t-shirt"] = {item = %s, texture = %s},\n	["vest"] = {item = %s, texture = %s},\n	["torso2"] = {item = %s, texture = %s},\n	["shoes"] = {item = %s, texture = %s},\n	["accessory"] = {item = %s, texture = %s},\n	["bag"] = {item = %s, texture = %s},\n	["hat"] = {item = %s, texture = %s},\n	["glass"] = {item = %s, texture = %s},\n	["mask"] = {item = %s, texture = %s},\n	["ear"] = {item = %s, texture = %s}\n}\n-------------------------------------------------\n',
				pants,
				pantst,
				arms,
				armst,
				shirt,
				shirtt,
				vest,
				vestt,
				torso,
				torsot,
				shoes,
				shoest,
				acc,
				acct,
				bag,
				bagt,
				hat,
				hatt,
				glass,
				glasst,
				mask,
				maskt,
				ear,
				eart
			)
			
			saveToFile(table)
		end,
	},
	{
		name = '💣 '..Lang:t("menu.ne_deleter"),
		marker = {
			type = 42,
			offset = vector3(0,0,0),
			scale = 1.0,
			color = {255, 255, 255, 150},
		},
		entityBox = true,
		rayFlags = 23,
		click = function(location, heading, entity, networked)
			if entity then
				if networked then
					if not IsEntityAPed(entity) or not IsPedAPlayer(entity) then
						local owner = GetPlayerServerId(NetworkGetEntityOwner(entity))
						TriggerServerEvent('demmycam:deletenetworked', owner, NetworkGetNetworkIdFromEntity(entity))
					end
				end
			end
		end,
	}]]--
}

function drawModeText()
	local modeName = MODES[MODE].name

	if modeName ~= "" then
		BeginTextCommandDisplayText('DCAMMODE')
	end

	SetTextScale(0.4,0.4)
	SetTextOutline()
	SetTextCentre(true)
	AddTextComponentInteger(MODE)
	AddTextComponentInteger(#MODES)
	AddTextComponentSubstringPlayerName(modeName)
	AddTextComponentInteger(SPEED)
	EndTextCommandDisplayText(0.5, 0.01)
end

function drawButtonsThisFrame()
	BeginScaleformMovieMethod(buttonsScaleform, 'CLEAR_ALL')
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, 'SET_CLEAR_SPACE')
	ScaleformMovieMethodAddParamInt(200)
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(0)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_PICKUP~")
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_COVER~")
	ScaleformMovieMethodAddParamTextureNameString(('Change Speed (%s %%)'):format(SPEED))
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(1)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_SPRINT~")
	ScaleformMovieMethodAddParamTextureNameString('Speed Boost')
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(2)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_SELECT_WEAPON~")
	ScaleformMovieMethodAddParamTextureNameString("Teleport")
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(3)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_MOVE_LR~")
	ScaleformMovieMethodAddParamTextureNameString("Turn Left/Right")
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(4)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_MOVE_UD~")
	ScaleformMovieMethodAddParamTextureNameString("Move")
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(5)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_AIM~")
	ScaleformMovieMethodAddParamTextureNameString(("Current Mode: %s"):format(MODES[MODE].name))
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, "SET_DATA_SLOT")
	ScaleformMovieMethodAddParamInt(6)
	ScaleformMovieMethodAddParamTextureNameString("~INPUT_ATTACK~")
	ScaleformMovieMethodAddParamTextureNameString("Select")
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
	EndScaleformMovieMethod()

	BeginScaleformMovieMethod(buttonsScaleform, 'SET_BACKGROUND_COLOUR')
	ScaleformMovieMethodAddParamInt(0)
	ScaleformMovieMethodAddParamInt(0)
	ScaleformMovieMethodAddParamInt(0)
	ScaleformMovieMethodAddParamInt(80)
	EndScaleformMovieMethod()

	DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)
end

function doCamFrame()
	if ACTIVE then
		disableFuckingEverything()
		local frameTime = GetFrameTime()
		local cam = getCam()

		local rotation = GetCamRot(cam,2)
		rotation = rotation + getMouseMovement()
		if rotation.x > 85 then
			rotation = vector3(85, rotation.y, rotation.z)
		elseif rotation.x < -85 then
			rotation = vector3(-85, rotation.y, rotation.z)
		end
		SetCamRot(cam, rotation, 2)

		local location = GetCamCoord(cam)
		local newLocation = getMovementInput(location, rotation, frameTime)
		SetCamCoord(cam, newLocation)

		if IsDisabledControlJustPressed(0, Config.Keys.SwitchMode) then
			if MODE + 1 > #MODES then
				MODE = 1
			else
				MODE = MODE + 1
			end
		end
		local modeData = MODES[MODE]

		if camType == 1 then
			drawButtonsThisFrame()
		else
			drawModeText()
		end

		local targetLocation = getRelativeLocation(location, rotation, 100)
		local ray = StartShapeTestRay(newLocation, targetLocation, modeData.rayFlags, 0)
		local someInt,hit,hitCoords,normal,entity = GetShapeTestResult(ray)

		local continue = true

		if hit then

			if not DoesEntityExist(entity) then
				entity = nil
			elseif not IsEntityAnObject(entity) and not IsEntityAPed(entity) and not IsEntityAVehicle(entity) then
				entity = nil
			end

			local r = 255
			local g = 0
			local b = 0
			local a = 40
			local networked = false

			if entity and NetworkGetEntityIsNetworked(entity) then
				if NetworkGetEntityOwner(entity) == PlayerId() then
					r = 0
					g = 255
				else
					r = 255
					g = 255
				end
				networked = true
			end

			if modeData.click and IsDisabledControlJustPressed(0, 24) then
				modeData.click(hitCoords, rotation.z, entity, networked)
			end

			if ACTIVE then -- It could have changed during click!

				if entity and modeData.entityBox and drawEntityBox(entity, r, g, b, a) then
					local model = drawEntityInfo(entity, hitCoords, networked)
				else
					DrawMarker(
						modeData.marker.type, -- Type
						hitCoords + modeData.marker.offset,
						0.0, 0.0, 0.0, -- Direction
						0.0, 0.0, rotation.z, -- Rotation
						modeData.marker.scale, modeData.marker.scale, modeData.marker.scale,
						modeData.marker.color[1], modeData.marker.color[2], modeData.marker.color[3], modeData.marker.color[4],
						false, -- bobs
						false, -- face camera
						2, -- Cargo Cult
						false, -- rotates
						0, 0, -- texture
						false -- projects on entities
					)
					if IsDisabledControlJustPressed(0, Config.Keys.Teleport) then
						if #(hitCoords - ZERO) > 0.25 then
							stopCam(true)
							Citizen.Wait(0)
							local playerPed = PlayerPedId()
							SetEntityCoords(playerPed, hitCoords, false, false, false, true)
							SetEntityHeading(playerPed, rotation.z)
							SetGameplayCamRelativeHeading(0.0)
							SetGameplayCamRelativePitch(rotation.x, 1.0)
						end
					end
				end
			end
		end

		if ACTIVE then -- because click might have deactivated
			SetFocusArea(location, ZERO)
			NetworkApplyVoiceProximityOverride(location)
		end
	end
end

Citizen.CreateThread(function()
	local ready = false
	while true do
		if ready then
			if not IsPauseMenuActive() then
				doCamFrame()
			end
			Citizen.Wait(0)
		else
			if NetworkIsSessionStarted() then
				ready = true
			else
				Citizen.Wait(100)
			end
		end
	end
end)

RegisterNetEvent('demmycam:nope')
AddEventHandler ('demmycam:nope', function()
	Citizen.CreateThread(function()
		Citizen.Wait(5000)
		PENDING = false
	end)
end)

canUse = false
RegisterNetEvent('qb-admin:client:TogglePrintDev')
AddEventHandler ('qb-admin:client:TogglePrintDev', function()
	canUse = not canUse
end)

RegisterNetEvent('demmycam:delete')
AddEventHandler ('demmycam:delete', function(netID)
	local entity = NetworkGetEntityFromNetworkId(netID)
	if entity and DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
		SetEntityAsMissionEntity(entity)
		DeleteEntity(entity)
	end
end)

inCam = false
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		if canUse then
			if IsControlPressed(0, 121) then
				if not inCam then
					startCam()
					inCam = true
				end
				Citizen.Wait(200)
			end
			
			if IsDisabledControlJustPressed(0, 121) then
				stopCam()
				inCam  = false
				Citizen.Wait(200)
			end
		else
			if inCam then
				stopCam()
			end
		end
	end
end)
