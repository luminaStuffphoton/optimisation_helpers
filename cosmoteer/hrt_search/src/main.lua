local drawSize = 20
local cellSize = 300 / (drawSize)

-- Note: all costs are in thousands of credits
-- Note: all heat values are in thousands of heat

local params = {
	power = {
		turret = 1.75,
		amp = 0.4,
		dila = 0.5,
	},
	heat = {
		turret = 600,
		amp = 200,
		dila = 200,
	},
	ampBase = 1.1,
	dilaBase = 0.5,
	dilaUtil = 1,
	baseHeat = 2.25,
	dilaHeat = 1.4, -- hardcoded from simulations. 100% dialation means 1400 more heat/s

	tilecost = 0,
	heatCost = nil, -- set in regenerateCosts()
	powerCost = nil, -- set in regenerateCosts()

	minOverload = 0,
	sustain = 1,
}


local function regenerateCosts()
	params.costs = {
		turret = 16  + 16*params.tilecost + 4*0.65 + 0.1, -- HRT Turret, including crew and doors
		amp    = 4.5 +  4*params.tilecost + 0.35,         -- Amplifier, including doors, half a heatpipe and a walkway
		dila   = 5   +  6*params.tilecost + 0.6,          -- Dilator, including doors, a heatpipe and two walkways
	}
	params.heatCost = (10 + 3*params.tilecost) / 1100
	params.powerCost = (50 + 9*params.tilecost + 1400*params.heatCost) / 11.25 -- Cost of 1 battery/s from an OCMR
			+ 1.88 * (0.7 + 2/3 * params.tilecost) -- Crew cost to deliver it 3 tiles through double walkway
end

regenerateCosts()

love.window.setMode(1200, 800)
love.keyboard.setKeyRepeat(true)
love.window.setTitle("Cosmo Heat Ray Turret Optimiser")

local xOffset = 0
local yOffset = 0
local cellSize = 120
local lx, ly

local function getPower(setup)
	return ((setup.turret * params.power.turret)
				+ (setup.amp * params.power.amp + setup.dila * params.power.dila) * setup.turret)
			* params.sustain
end

local function getHeat(setup)
	return ((setup.turret * params.heat.turret)
				+ (setup.amp * params.heat.amp + setup.dila * params.heat.dila) * setup.turret)
			* params.sustain
end

local function getOverload(setup)
	local pumpFactor = (setup.turret/2 + 0.5) ^ (-0.5)
	return 0.01 * ((4.4)
			+ (0.6 * (1 + setup.amp * pumpFactor * params.ampBase))
			+ (10 * (0.5 + setup.dila * pumpFactor * params.dilaBase)))
end


local function getCost(setup)
	return (setup.turret * params.costs.turret + setup.amp * params.costs.amp + setup.dila * params.costs.dila)
			+ (getPower(setup) * params.powerCost + getHeat(setup) * params.heatCost)
end

-- Pump value factor = (turrets/2 + 0.5)^(-0.5)
local function getOutput(setup)
	local pumpFactor = (setup.turret/2 + 0.5) ^ (-0.5)
	return setup.turret * (params.baseHeat
				* ((1 + setup.amp * pumpFactor * params.ampBase) ^ 0.67)
			+ params.dilaHeat * (0.5 + setup.dila * pumpFactor * params.dilaBase) * params.dilaUtil)
end


local infoDone = false
local infoValid = true
local setupStacks = {}
local bestSetup = {}
local wantedCost = 500
local highestValue = 0
local highestValueSetup
local highestOutput = 0
local highestOutputSetup


local distMoved = 0
local mouseDown
local selectedCell
local advOpts

local maxEfficency = 0

local function centerSetup(setup)
	xOffset = (setup.turret - 3) * -cellSize
	yOffset = (setup.y      - 3) * -cellSize
end

local function regenerateSetups()
	local turretNum = 1
	setupStacks = {}
	while getCost({turret=turretNum, dila=0, amp=0,}) < wantedCost do
		setupStacks[turretNum] = {}
		local dilaNum = 0
		while getCost({turret=turretNum, dila=dilaNum, amp=0,}) < wantedCost do
			local ampNum = 0
			while getCost({turret=turretNum, dila=dilaNum, amp=ampNum}) < wantedCost do
				if getOverload({turret=turretNum, dila=dilaNum, amp=ampNum}) >= params.minOverload then
					local setup = {turret=turretNum, dila=dilaNum, amp=ampNum}
					setup.cost = getCost(setup)
					setup.heat = getOutput(setup)
					setup.efficency = setup.heat / setup.cost
					maxEfficency = math.max(setup.efficency, maxEfficency)
					table.insert(setupStacks[turretNum], setup)
				end
				ampNum = ampNum + 1
			end
			dilaNum = dilaNum + 1
		end
		table.sort(setupStacks[turretNum], function(a, b)
			return a.cost < b.cost
		end)
		turretNum = turretNum + 1
	end

	if not (setupStacks[1] and setupStacks[1][1]) then
		infoValid = false
		return
	end
	infoValid = true

	highestValue = 0
	highestOutput = 0

	for _, setups in pairs(setupStacks) do
		for y, setup in pairs(setups) do
			local mult = math.floor(wantedCost / setup.cost)
			setup.mult = mult
			local output = mult * setup.heat

			if output > highestOutput then
				highestOutput = output
				if highestOutputSetup then
					highestOutputSetup.bestOutput = nil
				end
				setup.bestOutput = true
				setup.y = y
				highestOutputSetup = setup
			end
			if setup.efficency > highestValue then
				highestValue = setup.efficency
				if highestValueSetup then
					highestValueSetup.bestValue = nil
				end
				setup.bestValue = true
				setup.y = y
				highestValueSetup = setup
			end
		end
	end

	selectedCell = highestOutputSetup
	centerSetup(highestOutputSetup)
end

function love.update()
	if not infoDone then
		regenerateSetups()
		infoDone = true
	end
end

local function drawCell(drawX, drawY, entry)

	if entry.bestOutput and entry.bestValue then
		love.graphics.setColor(0, 0, 1)
	elseif entry.bestOutput then
		love.graphics.setColor(0.8, 0, 0.8)
	elseif entry.bestValue then
		love.graphics.setColor(0, 0.8, 0.8)
	else
		local efficencyProp = (entry.efficency/maxEfficency)^2
		love.graphics.setColor(0.8 * (1-efficencyProp), 0.8 * (efficencyProp), 0)
	end
	love.graphics.rectangle("fill", drawX, drawY, 100, 100)
	love.graphics.setColor(1, 1, 1)
	love.graphics.printf(entry.amp.." Amps\n"
			..entry.dila.." Dilators\n$"
			..math.floor(entry.cost+0.5).."k\n"
			..(math.floor(entry.heat*100 + 0.5) / 100).." GW\n"
			..(math.floor(entry.efficency * 1000 + 0.5)).." kW/$",
			drawX+5, drawY+5, 100/1.2, "left", 0, 1.2, 1.2)

	if entry == selectedCell then
		love.graphics.setColor(1, 1, 0)
		love.graphics.setLineWidth(5)
		love.graphics.rectangle("line", drawX, drawY, 100, 100)
	end
end

function love.keypressed(key, isrepeat)
	infoDone = false
	if     key == "q" then
		if advOpts then
			params.tilecost = params.tilecost + 0.01
			regenerateCosts()
		else wantedCost = wantedCost + 10 end
	elseif key == "a" then
		if advOpts then
			params.tilecost = math.max(params.tilecost - 0.01, 0)
			regenerateCosts()
		else wantedCost = math.max(wantedCost - 10, 0) end
	elseif key == "w" then
		params.sustain = math.min(params.sustain + 0.05, 1)
	elseif key == "s" then
		params.sustain = math.max(params.sustain - 0.05, 0)
	elseif key == "e" then
		params.minOverload = params.minOverload + 0.1
	elseif key == "d" then
		params.minOverload = math.max(params.minOverload - 0.1, 0)
	elseif key == "z" then
		selectedCell = highestOutputSetup
		centerSetup(highestOutputSetup)
		infoDone = true
	elseif key == "x" then
		selectedCell = highestValueSetup
		centerSetup(highestValueSetup)
		infoDone = true
	elseif key == "1" then
		advOpts = false
		infoDone = true
	elseif key == "2" then
		advOpts = true
		infoDone = true
	else
		infoDone = true
	end
end

function love.draw()
	if infoDone and infoValid then
		xOffset = math.max(math.min(xOffset, 100), -cellSize * (#setupStacks))
		yOffset = math.max(math.min(yOffset, 0), -cellSize * (#(setupStacks[1])))

		for column, entries in pairs(setupStacks) do
			local drawX = xOffset + (column - 0) * cellSize
			if drawX < 800 then
				for row, entry in pairs(entries) do
					local drawY = yOffset + (row - 0) * cellSize
					if drawY < 800 then
						drawCell(drawX, drawY, entry)
					end
				end
			end

			love.graphics.setColor(0, 0, 0)
			love.graphics.rectangle("fill", drawX-20, 0, 140, 100)
			love.graphics.setColor(1, 1, 1)
			love.graphics.printf(column .. " Turrets", drawX-25, 50, 100, "center", 0, 1.5, 1.5)
		end


		if love.mouse.isDown(1) then
			x, y = love.mouse.getPosition()
			if x < 800 and y < 800 then
				xOffset = xOffset - (lx - x)
				yOffset = yOffset - (ly - y)
				distMoved = distMoved + math.sqrt((lx - x)^2 + (ly - y)^2)
			end
			mouseDown = true
		else
			if mouseDown and distMoved < 25 then
				local mx, my = love.mouse.getPosition()
				mx, my = mx - xOffset, my - yOffset
				local cx, cy = math.floor(mx / cellSize), math.floor(my / cellSize)
				print("selecting ("..cx..", "..cy..")")

				if setupStacks[cx] and setupStacks[cx][cy] then
					selectedCell = setupStacks[cx][cy]
				end
			end
			distMoved = 0
			mouseDown = false
		end
	elseif infoDone then
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("No valid setups able to be found!\nCheck your settings to make sure there is a big enough budget", 200, 300, 400/2, "center", 0, 2, 2)
	else
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Generating entries", 0, 400, 400, "center", 0, 2, 2)
	end

	lx, ly = love.mouse.getPosition()

	love.graphics.setColor(0.2, 0.2, 0.2)
	love.graphics.rectangle("fill", 800, 0, 400, 800)

	local info = "== Information =="
			.."\nThe menu on the right shows all the resonance lance setups that will fit into the allocated budget. Click-and-drag in order to scroll through the avalible options. The setups are sorted vertically by their cost."
			.."\n\nSetups are colour coded by efficency, with red representing worse efficecy and green representing best efficency."
			.."\n\nThe setup shaded in purple is the best setup in terms of heat/s within your allocated budget. The setup outlined in cyan is the best setup in terms of pure efficecy, but may not fit neatly under your budget. A setup is shaded in blue if it is both best heat/s and best efficecy."
			.."\n\n== Parameters =="
	if not advOpts then info = info
			.."\nPress 2 to view advanced options"
			.."\n\tBudget: $"..wantedCost.."k"
			.."\n\t\t(Increase with Q, decrease with A)"
			.."\n\tSustain: "..math.floor(params.sustain*100 + 0.5).."%"
			.."\n\t\t(Increase with W, decrease with S)"
			.."\n\tMin Shield Overload: "..math.floor(params.minOverload*100 + 0.5).."%"
			.."\n\t\t(Increase with E, decrease with D)"
	else info = info
			.."\nPress 1 to view basic options"
			.."\n\tVolume Penalty: $"..math.floor(params.tilecost*1000+0.5)..""
			.."\n\t\t(Increase with Q, decrease with A)"
	end
	if infoValid then info = info
			.."\n\n== Selected Setup =="
			.."\nThe setup outlined in yellow is the selected setup."
				..(selectedCell.bestOutput and " You have selected the best heat/s setup." or "")
				..(selectedCell.bestValue  and " You have selected the best efficency setup." or "")
			.."\n\nThe selected setup is "..selectedCell.mult.." copies of the following:"
			.."\n\t"..selectedCell.turret.." Turrets, "..selectedCell.amp.." Amplifiers, "..selectedCell.dila.." Dilators."
			.."\n\nThe selected setup:"
			.."\n\tCosts $"..math.floor(selectedCell.cost * selectedCell.mult).."k for all copies"
			.."\n\tUses "..(math.floor(getPower(selectedCell) * 10 + 0.5) / 10).." batteries/s per copy"
			.."\n\tGenerates "..(math.floor(getHeat(selectedCell) * 10 + 0.5) / 10).." heat/s for all copies"
			.."\n\tAfflicts "..(math.floor(getOverload(selectedCell) * 100 + 0.5)).."% shield overload"
			.."\n\nPress Z to jump to the best setup in terms of heat/s within budget."
			.."\nPress X to jump to the best setup in terms of efficency."
	end


	love.graphics.setColor(1, 1, 1)
	love.graphics.printf(info, 820, 20, 360/1.2, "left", 0, 1.2, 1.2)
	--love.graphics.printf(internals, 700, 400, 400, "left", 0, 1.2, 1.2)
	--love.graphics.printf(effects, 700, 575, 400, "left", 0, 1.2, 1.2)
end
