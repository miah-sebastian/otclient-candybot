-- Auto Healing Logic
SupportModule.AutoHeal = {}
AutoHeal = SupportModule.AutoHeal

local nextHeal = {}
local lastCast = 0
local lastUse = 0
local lastUseDelay = 0
local castTimeOut = 0
local useTimeOut = 0

local spellLastUse = {}
local spellCooldowns = {}
local groupCooldowns = {}
local groupLastUse = {}

local settings = {
  [RestoreType.cast] = 'AutoHeal',
  [RestoreType.item] = 'AutoHealthItem'
}

function AutoHeal.onSpellCooldown(spellId, delay)
	spellCooldowns[spellId] = delay/1000
	spellLastUse[spellId] = os.clock()
	return
end

function AutoHeal.onSpellGroupCooldown(groupId, delay)
	groupCooldowns[groupId] = delay/1000
	groupLastUse[groupId] = os.clock()
	return
end

function AutoHeal.onMultiUseCooldown(delay)
	lastUseDelay = delay/1000
	lastUse = os.clock()
	return
end

function AutoHeal.getNextGroupUse(spellId)
	local currentTime = os.clock()
	local spell = Spells.getSpellByIcon(spellId)
	local spellgroups = spell.group
	local highestNextUse = 0
	for k, v in pairs(spellgroups) do
		local group = k
		local groupcd = v
		local groupLastUse = groupLastUse[group]
		if groupLastUse and groupLastUse + groupcd > highestNextUse then
			highestNextUse = groupLastUse + (groupcd/1000)
		end
	end
	return highestNextUse
end

function AutoHeal.getNextUse(spellId)
	local currentTime = os.clock()
	local spell = Spells.getSpellByIcon(spellId)
	local cooldownDelay = spell.exhaustion/1000
	local lastSpellUse = spellLastUse[spellId]
	local nextGroupUse = AutoHeal.getNextGroupUse(spellId)
	local delayCheck = cooldownDelay or 0
	local lastUseCheck = lastSpellUse or 0
	local finalCheckBool = nextGroupUse > delayCheck + lastUseCheck
	local finalCheck = finalCheckBool and nextGroupUse or delayCheck + lastUseCheck
	return finalCheck
end

function AutoHeal.execute(player, restoreType)
	local currentTime = os.clock()
	local Panel = SupportModule.getPanel()
	if not Panel:getChildById(settings[restoreType]):isChecked() then
		return -- has since been unchecked
	end

  if restoreType == RestoreType.cast then
	local spellText = false
    local healthValue = 0
	local delay = 1
	for i = 1, 3 do
		local ithing = i == 1
		ithing = not ithing and "" .. i or ""
		if Panel:getChildById('AutoHeal' .. ithing ):isChecked() then
			local tmpSpellText = Panel:getChildById('HealSpellText' .. ithing):getText()
			local tmpHealthValue = Panel:getChildById('HealthBar' .. ithing):getValue()
			local spell = Spells.getSpellByWords(tmpSpellText)
			local spellCheck = spell ~= nil
			local spellCooldown = spellCheck and AutoHeal.getNextUse(spell.id) or 0
			local ping = g_game.getPing()/1000
			local timeCheck = spellCooldown - currentTime - ping or 0
			local lastCheck = timeCheck > 0
			local tmpDelay = lastCheck and timeCheck or 0
			local spellMana = spell.mana
			local spellManaCheck = spellMana and spellMana > 0
			local spellManaCheck2 = spellManaCheck and spellMana or 0
			if player:getHealthPercent() < tmpHealthValue and tmpDelay == 0 and player:getMana() >= spellManaCheck2 then
				spellText = tmpSpellText
				healthValue = tmpHealthValue
				delay = tmpDelay
				break
			end
		end
	end
    if spellText and delay == 0 and castTimeOut < currentTime then
	local spell = Spells.getSpellByWords(spellText)
		g_logger.debug("tried:" .. currentTime)
		castTimeOut = currentTime + 0.5
      g_game.talk(spellText)
	  if nextHeal[RestoreType.cast] then
		removeEvent(nextHeal[RestoreType.cast])
	  end
    end
	if nextHeal[RestoreType.cast] then
		removeEvent(nextHeal[RestoreType.cast])
	end
	local delayCheck = delay > 100
	local nextUse = delayCheck and delayCheck or 100
	nextHeal[RestoreType.cast] = scheduleEvent(function()
		local player = g_game.getLocalPlayer()
		if not player then return end
		AutoHeal.execute(player, restoreType)
	end, nextUse)
  elseif restoreType == RestoreType.item then
    local item = Panel:getChildById('CurrentHealthItem'):getItem()
    if not item then
      Panel:getChildById('AutoHealthItem'):setChecked(false)
      return
    end
    local healthValue = Panel:getChildById('ItemHealthBar'):getValue()
	local itemCheck = item ~= nil
	local itemCooldown = itemCheck and lastUse + lastUseDelay or 0
    
	local ping = g_game.getPing()/1000
	local timeCheck = itemCooldown - ping - currentTime or 0
	local lastCheck = timeCheck > 0
    local delay = lastCheck and timeCheck or 0
    if player:getHealthPercent() < healthValue and delay == 0 and useTimeOut < currentTime then
		g_logger.debug("tried2:" .. currentTime)
		useTimeOut = currentTime + 0.5
      Helper.safeUseInventoryItemWith(item:getId(), player, BotModule.isPrecisionMode())
	--BotLogger.debug("".. delay)
	  if nextHeal[RestoreType.item] then
		removeEvent(nextHeal[RestoreType.item])
	  end
    end
	if nextHeal[RestoreType.item] then
		removeEvent(nextHeal[RestoreType.item])
	end
	local delayCheck = delay > 100
	local nextUse = delayCheck and delayCheck or 100
	nextHeal[RestoreType.item] = scheduleEvent(function()
		local player = g_game.getLocalPlayer()
		if not player then return end
		AutoHeal.execute(player, restoreType)
	end, nextUse)
  end
  return
end

function AutoHeal.onTextMessage(mode, message)
	if mode == 19 and message == "You are exhausted." then
		local currentTime = os.clock()
		local player = g_game.getLocalPlayer()
		if not player then return end
		local ping = g_game.getPing()/1000
		g_logger.debug("TRIGGERED! " .. currentTime)
		if lastCast - currentTime < ping then
			castTimeOut = currentTime
			AutoHeal.execute(player, RestoreType.cast)
		end
		if lastUse - currentTime < ping then
			useTimeOut = currentTime
			AutoHeal.execute(player, RestoreType.item)
		end
	end
	return
end

function AutoHeal.onTalk(name, level, mode, message, channelId, creaturePos)
    local player = g_game.getLocalPlayer()
    if not player then return end
	local Panel = SupportModule.getPanel()
	if not Panel:getChildById(settings[RestoreType.cast]):isChecked() then
		return -- has since been unchecked
	end
	local spellText = Panel:getChildById('HealSpellText'):getText()
	local spellText2 = Panel:getChildById('HealSpellText2'):getText()
	local spellText3 = Panel:getChildById('HealSpellText3'):getText()
	local messagebool = message == spellText or message == spellText2 or message == spellText3
	local playerName = player:getName()
	if name == playerName and mode == MessageModes.BarkLow and messagebool then
		lastCast = os.clock()
		if nextHeal[RestoreType.cast] then
			removeEvent(nextHeal[RestoreType.cast])
		end
		local player = g_game.getLocalPlayer()
		if not player then return end
		local spell = Spells.getSpellByWords(message)
		local spellCheck = spell ~= nil
		local cooldownDelay = spellCheck and spellCooldowns[spell.id]
		local delay = cooldownDelay or 1000

		nextHeal[RestoreType.cast] = scheduleEvent(AutoHeal.execute(player, RestoreType.cast), delay)
	end
	return
end

function AutoHeal.onHealthChange(player, health, maxHealth, oldHealth, restoreType)
  local currentTime = os.clock()
  local Panel = SupportModule.getPanel()
  if not Panel:getChildById(settings[restoreType]):isChecked() then
    return -- has since been unchecked
  end

  if restoreType == RestoreType.cast then

	local spellText = false
    local healthValue = 0
	local delay = 1
	for i = 1, 3 do
		local ithing = i == 1
		ithing = not ithing and "" .. i or ""
		if Panel:getChildById('AutoHeal' .. ithing ):isChecked() then
			local tmpSpellText = Panel:getChildById('HealSpellText' .. ithing):getText()
			local tmpHealthValue = Panel:getChildById('HealthBar' .. ithing):getValue()
			local spell = Spells.getSpellByWords(tmpSpellText)
			local spellCheck = spell ~= nil
			local spellCooldown = spellCheck and AutoHeal.getNextUse(spell.id) or 0
			local ping = g_game.getPing()/1000
			local timeCheck = spellCooldown - ping - currentTime or 0
			local lastCheck = timeCheck > 0
			local tmpDelay = lastCheck and timeCheck or 0
			local spellMana = spell.mana
			local spellManaCheck = spellMana and spellMana > 0
			local spellManaCheck2 = spellManaCheck and spellMana or 0
			if player:getHealthPercent() < tmpHealthValue and tmpDelay == 0 and player:getMana() >= spellManaCheck2 then
				spellText = tmpSpellText
				healthValue = tmpHealthValue
				delay = tmpDelay
				break
			end
		end
	end
    if spellText and delay == 0 then
      --g_game.talk(spellText)
	  if nextHeal[RestoreType.cast] then
		removeEvent(nextHeal[RestoreType.cast])
	  end
    end

	AutoHeal.execute(player, restoreType)
	return

  elseif restoreType == RestoreType.item then

    local item = Panel:getChildById('CurrentHealthItem'):getItem()
    if not item then
      Panel:getChildById('AutoHealthItem'):setChecked(false)
      return
    end

    local healthValue = Panel:getChildById('ItemHealthBar'):getValue()
	local itemCheck = item ~= nil
	local itemCooldown = itemCheck and lastUse + lastUseDelay or 0
    
	local ping = g_game.getPing()/1000
	local timeCheck = itemCooldown - ping - currentTime or 0
	local lastCheck = timeCheck > 0
    local delay = lastCheck and timeCheck or 0
	--BotLogger.debug("".. delay)
    if player:getHealthPercent() < healthValue and delay == 0 then
      --g_game.talk(spellText)
	  if nextHeal[RestoreType.item] then
		removeEvent(nextHeal[RestoreType.item])
	  end
    end
	AutoHeal.execute(player, restoreType)
	return
  end
end

function AutoHeal.executeCast(player, health, maxHealth, oldHealth)
  AutoHeal.onHealthChange(player, health, maxHealth, oldHealth, RestoreType.cast)
end

function AutoHeal.ConnectCastListener(listener)
  if g_game.isOnline() then
    local player = g_game.getLocalPlayer()
    addEvent(AutoHeal.onHealthChange(player, player:getHealth(),
      player:getMaxHealth(), player:getHealth(), RestoreType.cast))
  end

  connect(LocalPlayer, { onHealthChange = AutoHeal.executeCast })
  connect(g_game, { onTalk = AutoHeal.onTalk,
					onSpellCooldown = AutoHeal.onSpellCooldown,
					onSpellGroupCooldown = AutoHeal.onSpellGroupCooldown,
					onTextMessage = AutoHeal.onTextMessage})
end

function AutoHeal.DisconnectCastListener(listener)
  disconnect(LocalPlayer, { onHealthChange = AutoHeal.executeCast })
  disconnect(g_game, { onTalk = AutoHeal.onTalk,
					onSpellCooldown = AutoHeal.onSpellCooldown,
					onSpellGroupCooldown = AutoHeal.onSpellGroupCooldown,
					onTextMessage = AutoHeal.onTextMessage})
end

function AutoHeal.executeItem(player, health, maxHealth, oldHealth)
  AutoHeal.onHealthChange(player, health, maxHealth, oldHealth, RestoreType.item)
end

function AutoHeal.ConnectItemListener(listener)
  if g_game.isOnline() then
    local player = g_game.getLocalPlayer()
    addEvent(AutoHeal.onHealthChange(player, player:getHealth(),
      player:getMaxHealth(), player:getHealth(), RestoreType.item))
  end

  connect(LocalPlayer, { onHealthChange = AutoHeal.executeItem })
  connect(g_game, { onMultiUseCooldown = AutoHeal.onMultiUseCooldown })
end

function AutoHeal.DisconnectItemListener(listener)
  disconnect(LocalPlayer, { onHealthChange = AutoHeal.executeItem })
  disconnect(g_game, { onMultiUseCooldown = AutoHeal.onMultiUseCooldown })
end