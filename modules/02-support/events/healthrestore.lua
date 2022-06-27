-- Auto Healing Logic
SupportModule.AutoHeal = {}
AutoHeal = SupportModule.AutoHeal

local nextHeal = {}
local lastCast = 0
local lastUse = 0
local lastUseDelay = 0

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

function AutoHeal.getNextUse(spellId)
	local cooldownDelay = spellCooldowns[spellId]
	local lastSpellUse = spellLastUse[spellId]
	local delayCheck = cooldownDelay or 0
	local lastUseCheck = lastSpellUse or 0
	return delayCheck + lastUseCheck
end

function AutoHeal.onTalk(name, level, mode, message, channelId, creaturePos)
    local player = g_game.getLocalPlayer()
    if not player then return end
	local Panel = SupportModule.getPanel()
	if not Panel:getChildById(settings[RestoreType.cast]):isChecked() then
		return -- has since been unchecked
	end
	local spellText = Panel:getChildById('HealSpellText'):getText()
	local playerName = player:getName()
	if name == playerName and mode == MessageModes.BarkLow and message == spellText then
		lastCast = os.clock()
		if nextHeal[RestoreType.cast] then
			removeEvent(nextHeal[RestoreType.cast])
		end
		local player = g_game.getLocalPlayer()
		if not player then return end
		local cooldownDelay = spellCooldowns[spellId]
		local delay = cooldownDelay or 1000

		nextHeal[RestoreType.cast] = scheduleEvent(AutoHeal.onHealthChange(player,
		player:getHealth(), player:getMaxHealth(), player:getHealth(),
		RestoreType.cast), delay)
	end
	return
end

function AutoHeal.execute(player)
	local currentTime = os.clock()
	local Panel = SupportModule.getPanel()
	if not Panel:getChildById(settings[RestoreType.cast]):isChecked() then
		return -- has since been unchecked
	end
	local spellText = Panel:getChildById('HealSpellText'):getText()
    local healthValue = Panel:getChildById('HealthBar'):getValue()
	local spell = Spells.getSpellByWords(spellText)
	local spellCheck = spell ~= nil
	local spellCooldown = spellCheck and AutoHeal.getNextUse(spell.id) or 0
    
	local ping = g_game.getPing()/1000
	local timeCheck = spellCooldown - ping - currentTime or 0
	local lastCheck = timeCheck > 0
    local delay = lastCheck and timeCheck or 0
    if player:getHealthPercent() < healthValue and delay == 0 then
      g_game.talk(spellText)
	BotLogger.debug("".. delay)
	  if nextHeal[RestoreType.cast] then
		removeEvent(nextHeal[RestoreType.cast])
	  end
    end
	if nextHeal[RestoreType.cast] then
		removeEvent(nextHeal[RestoreType.cast])
	end
	nextHeal[RestoreType.cast] = scheduleEvent(function()
		local player = g_game.getLocalPlayer()
		if not player then return end
		AutoHeal.execute(player)
	end, 100)
	return
end
		

function AutoHeal.onHealthChange(player, health, maxHealth, oldHealth, restoreType)
  local currentTime = os.clock()
  local Panel = SupportModule.getPanel()
  if not Panel:getChildById(settings[restoreType]):isChecked() then
    return -- has since been unchecked
  end

  if restoreType == RestoreType.cast then
    local spellText = Panel:getChildById('HealSpellText'):getText()
    local healthValue = Panel:getChildById('HealthBar'):getValue()
	local spell = Spells.getSpellByWords(spellText)
	local spellCheck = spell ~= nil
	local spellCooldown = spellCheck and AutoHeal.getNextUse(spell.id) or 0
    
	local ping = g_game.getPing()/1000
	local timeCheck = spellCooldown - ping - currentTime or 0
	local lastCheck = timeCheck > 0
    local delay = lastCheck and timeCheck or 0
	--BotLogger.debug("".. delay)
    if player:getHealthPercent() < healthValue and delay == 0 then
      --g_game.talk(spellText)
	  if nextHeal[RestoreType.cast] then
		removeEvent(nextHeal[RestoreType.cast])
	  end
    end

	AutoHeal.execute(player)
	return

  elseif restoreType == RestoreType.item then

    local item = Panel:getChildById('CurrentHealthItem'):getItem()
    if not item then
      Panel:getChildById('AutoHealthItem'):setChecked(false)
      return
    end

    local healthValue = Panel:getChildById('ItemHealthBar'):getValue()
    local delay = Helper.getItemUseDelay()

    if player:getHealthPercent() < healthValue then
      Helper.safeUseInventoryItemWith(item:getId(), player, BotModule.isPrecisionMode())
    end

    nextHeal[RestoreType.item] = scheduleEvent(function()
      local player = g_game.getLocalPlayer()
      if not player then return end
      health, maxHealth = player:getHealth(), player:getMaxHealth()
      if player:getHealthPercent() < healthValue then
        AutoHeal.onHealthChange(player, health, maxHealth, health, restoreType) 
      else
        removeEvent(nextHeal[RestoreType.item])
      end
    end, delay)
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
					onSpellGroupCooldown = AutoHeal.onSpellGroupCooldown})
end

function AutoHeal.DisconnectCastListener(listener)
  disconnect(LocalPlayer, { onHealthChange = AutoHeal.executeCast })
  disconnect(g_game, { onTalk = AutoHeal.onTalk,
					onSpellCooldown = AutoHeal.onSpellCooldown,
					onSpellGroupCooldown = AutoHeal.onSpellGroupCooldown})
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