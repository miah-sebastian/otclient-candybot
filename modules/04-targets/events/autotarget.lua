--[[
  @Authors: Ben Dol (BeniS)
  @Details: Auto targeting event logic
]]

TargetsModule.AutoTarget = {}
AutoTarget = TargetsModule.AutoTarget

-- Variables

AutoTarget.creatureData = {}

-- Methods

function AutoTarget.init()
  connect(Creature, { onAppear = AutoTarget.addCreature })
  connect(TargetsModule, { onAddTarget = AutoTarget.scan })
  connect(g_game, { onAttackingCreatureChange = AutoTarget.targetChanged })
end

function AutoTarget.terminate()
  disconnect(Creature, { onAppear = AutoTarget.addCreature })
  disconnect(TargetsModule, { onAddTarget = AutoTarget.scan })
  disconnect(g_game, { onAttackingCreatureChange = AutoTarget.targetChanged })
end

function AutoTarget.targetChanged(creature, oldCreature)
  AutoTarget.currentTarget = creature

  if AutoTarget.currentTarget then
    connect(AutoTarget.currentTarget, {
      onDeath = function(creature)
        local t = AutoTarget.currentTarget
        if t and t:getId() == creature:getId() then
          AutoTarget.currentTarget = nil
        end
      end
    })
  end
end

function AutoTarget.hasTargets()
  return AutoTarget.creatureData ~= nil and #AutoTarget.creatureData > 0
end

function AutoTarget.getCreatureData()
  return AutoTarget.creatureData
end

function AutoTarget.scan()
  print("scanning")
  local targetList = {}
  for k,v in pairs(TargetsModule.getTargets()) do
    table.insert(targetList, v:getName())
  end

  local player = g_game.getLocalPlayer()
  local targets = player:getTargetsInArea(targetList, true)

  for k,target in pairs(targets) do
    if not target:isDead() and not target:isRemoved() then
      if not AutoTarget.isAlreadyStored(target) then
        AutoTarget.addCreature(target)
      end
    else
      AutoTarget.removeCreature(target)
    end
  end
end

function AutoTarget.isAlreadyStored(creature)
  return AutoTarget.creatureData[creature:getId()] ~= nil
end

function AutoTarget.addCreature(creature)
  -- Avoid adding new targets when attacking
  if creature and creature:isMonster() then
    --connect(creature, { onHealthPercentChange = AutoTarget.onTargetHealthChange })
    connect(creature, { onDeath = AutoLoot.onTargetDeath })
    connect(creature, { onDisappear = AutoTarget.removeCreature })

    AutoTarget.creatureData[creature:getId()] = creature
  end
end

function AutoTarget.removeCreature(creature)
  if creature then
    --disconnect(creature, { onHealthPercentChange = AutoTarget.onTargetHealthChange })
    disconnect(creature, { onDeath = AutoLoot.onTargetDeath })
    disconnect(creature, { onDisappear = AutoTarget.removeCreature })

    AutoTarget.creatureData[creature:getId()] = nil
  end
end

function AutoTarget.onTargetHealthChange(creature)

end

function AutoTarget.isValidTarget(creature)
  local player = g_game.getLocalPlayer()
  return TargetsModule.hasTarget(creature:getName()) and player:canStandBy(creature)
end

function AutoTarget.getBestTarget()
  local player = g_game.getLocalPlayer()
  local playerPos = player:getPosition()
  local target, distance = nil, nil

  for id,t in pairs(AutoTarget.creatureData) do
    if t and AutoTarget.isValidTarget(t) then
      local d = Position.distance(playerPos, t:getPosition())
      if not target or d < distance then
        print("Found closest target")
        target = t
        distance = d
      end
    end
  end
  return target
end

function AutoTarget.onStopped()
  --
end

function AutoTarget.Event(event)
  -- Cannot continue if still attacking or looting
  if g_game.isAttacking() then
    EventHandler.rescheduleEvent(TargetsModule.getModuleId(), 
      event, Helper.safeDelay(600, 2000))
    return
  end

  -- Find a valid target to attack
  local target = AutoTarget.getBestTarget()
  if target then
    -- If looting pause to prioritize targeting
    if AutoLoot.isLooting() then
      AutoLoot.pauseLooting()
    end

    g_game.attack(target)
  end

  -- Keep the event live
  EventHandler.rescheduleEvent(TargetsModule.getModuleId(), 
    event, Helper.safeDelay(600, 1400))
end