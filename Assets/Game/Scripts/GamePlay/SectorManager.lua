---@gendoc

local GameSoundType = Ballance2.Services.GameSoundType
local DebugUtils = Ballance2.Utils.DebugUtils
local Log = Ballance2.Log
local Yield = UnityEngine.Yield

---节管理器，负责控制关卡游戏中每个小节机关的状态。
---@class SectorManager : GameLuaObjectHostClass
SectorManager = ClassicObject:extend()

---小节数据存储结构
---@class SectorDataStorage
---@field moduls ModulBase[] 当前小节的所有机关实例
SectorDataStorage = {}

---出生点数据存储结构
---@class RestPointsDataStorage
---@field point GameObject 出生点占位符对象
---@field flame PC_TwoFlames 火焰机关
RestPointsDataStorage = {}

local TAG = 'SectorManager'

function SectorManager:new() 
  self.CurrentLevelSectorCount = 0
  self.CurrentLevelModulCount = 0
  self.CurrentLevelSectors = {} ---@type SectorDataStorage[]
  self.CurrentLevelRestPoints = {} ---@type RestPointsDataStorage[]
  self.CurrentLevelEndBalloon = nil ---@type PE_Balloon
end
function SectorManager:Start() 
  GamePlay.SectorManager = self

  local events = Game.Mediator:RegisterEventEmitter('SectorManager')
  self.EventSectorDeactive = events:RegisterEvent('SectorDeactive') --小节结束事件
  self.EventSectorChanged = events:RegisterEvent('SectorChanged') --节更改事件
  self.EventSectorActive = events:RegisterEvent('SectorActive') --小节激活事件
  self.EventResetAllSector = events:RegisterEvent('ResetAllSector') --所有节重置事件
  
  self._CommandId = Game.Manager.GameDebugCommandServer:RegisterCommand('sector', function (eyword, fullCmd, argsCount, args)
    local type = args[1]
    if type == 'next' then
      self:NextSector()
    elseif type == 'set' then
      local o, n = DebugUtils.CheckIntDebugParam(1, args, Slua.out, true, 1)
      if not o then return false end

      self:SetCurrentSector(n)
    elseif type == 'reset' then
      local o, n = DebugUtils.CheckIntDebugParam(1, args, Slua.out, true, 1)
      if not o then return false end

      self:ResetCurrentSector(n)
    elseif type == 'reset-all' then
      self:ResetAllSector(true)
    else
      Log.W(TAG, 'Unknow option '..type)
      return false
    end
    return true
  end, 1, "sector <next/set/reset/reset-all> 节管理器命令"..
          "  next                  ▶ 进入下一小节"..
          "  set <sector:number>   ▶ 设置当前激活的小节"..
          "  reset <sector:number> ▶ 重置指定的小节机关"..
          "  reset-all             ▶ 重置所有小节"
  )
end
function SectorManager:OnDestroy() 
  Game.Mediator:UnRegisterEventEmitter('SectorManager')
  Game.Manager.GameDebugCommandServer:UnRegisterCommand(self._CommandId)
end

function SectorManager:DoInitAllModuls() 
  self.CurrentLevelModulCount = 0
  --初次加载后通知每个modul进行备份
  for _, value in pairs(Game.LevelBuilder._CurrentLevelModuls) do
    if value ~= nil then
      value.modul:Backup()
      value.modul:Deactive()
      self.CurrentLevelModulCount = self.CurrentLevelModulCount + 1
    end
  end
end
function SectorManager:DoUnInitAllModuls() 
  local preview = Game.LevelBuilder.IsPreviewMode
  --通知每个modul卸载
  for _, value in pairs(Game.LevelBuilder._CurrentLevelModuls) do
    if value ~= nil then
      if preview then
        value.modul:DeactiveForPreview()
      else
        value.modul:Deactive()
      end
      value.modul:UnLoad()
    end
  end
end
function SectorManager:ClearAll() 
  self.CurrentLevelSectorCount = 0
  self.CurrentLevelSectors = {}
  self.CurrentLevelRestPoints = {}
  self.CurrentLevelEndBalloon = nil
end
function SectorManager:ActiveAllModulsForPreview() 
  --通知每个modul卸载
  for _, value in pairs(Game.LevelBuilder._CurrentLevelModuls) do
    if value ~= nil then
      value.modul:ActiveForPreview()
    end
  end
end

---进入下一小节
function SectorManager:NextSector() 
  if GamePlay.GamePlayManager.CurrentSector < self.CurrentLevelSectorCount then
    self:SetCurrentSector(GamePlay.GamePlayManager.CurrentSector + 1)
  end
end
---设置当前激活的小节
---@param sector number
function SectorManager:SetCurrentSector(sector) 
  local oldSector = GamePlay.GamePlayManager.CurrentSector
  if oldSector ~= sector then
    --禁用之前一节的所有机关
    if oldSector > 0 then
      local s = self.CurrentLevelSectors[oldSector]
      for _, value in pairs(s.moduls) do
        if value ~= nil then  
          value:Deactive()
        end
      end 
      
      --设置火焰状态
      local flame = self.CurrentLevelRestPoints[oldSector].flame
      if flame then
        flame.CheckPointActived = true
        flame:Deactive()
      else
        Log.D(TAG, "No flame found for sector "..oldSector)
      end

      self.EventSectorDeactive:Emit({ 
        oldSector = oldSector 
      })
    end

    if sector > 0 then 
      GamePlay.GamePlayManager.CurrentSector = sector 
      self:ActiveCurrentSector(true)
    end

    self.EventSectorChanged:Emit({ 
      sector = sector,
      oldSector = oldSector
    })
  end
end

---激活当前节的机关
---@param playCheckPointSound boolean 是否播放节点音乐
function SectorManager:ActiveCurrentSector(playCheckPointSound) 
  local sector = GamePlay.GamePlayManager.CurrentSector
  local nowSector = self.CurrentLevelRestPoints[sector]

  --设置火焰状态

  if nowSector.flame ~= nil then
    nowSector.flame:Active()
  else
    Log.D(TAG, "No flame found for sector "..sector)
  end
  if sector < self.CurrentLevelSectorCount then
    nowSector = self.CurrentLevelRestPoints[sector + 1]
    --下一关的火焰
    local flameNext = nowSector.flame
    if flameNext ~= nil then
      flameNext:InternalActive()
    end
  end

  --播放音乐
  if playCheckPointSound and sector > 1 then
    Game.SoundManager:PlayFastVoice('core.sounds:Misc_Checkpoint.wav', GameSoundType.Normal)
  end

  --如果是最后一个小节，则激活飞船
  if self.CurrentLevelEndBalloon ~= nil then
    if sector == self.CurrentLevelSectorCount then
      self.CurrentLevelEndBalloon:Active()
    else
      self.CurrentLevelEndBalloon:Deactive()
    end
  else
    Log.W(TAG, "No found CurrentLevelEndBalloon !")
  end

  Log.D(TAG, 'Active Sector '..sector)

  --激活当前节的机关
  local count = 0
  coroutine.resume(coroutine.create(function()
    local s = self.CurrentLevelSectors[sector]
    if s == nil and sector ~= 0 then
      Log.E(TAG, 'Sector '..sector..' not found')
      GamePlay.GamePlayManager.CurrentSector = 0 
      return
    end
    for _, value in pairs(s.moduls) do
      if value ~= nil then  
        value:Active()
      end
      --延时下防止一下生成过多机关
      count = count + 1
      if count > 16 then
        count = 0
        Yield(nil) 
      end
    end 

    --调试信息
    if BALLANCE_DEBUG then 
      GameUI.GamePlayUI._DebugStatValues['Sector'].Value = sector..'/'..self.CurrentLevelSectorCount
      GameUI.GamePlayUI._DebugStatValues['Moduls'].Value = (#s.moduls)..'/'..self.CurrentLevelModulCount
    end
  end))


  self.EventSectorActive:Emit({ 
    sector = sector,
    playCheckPointSound = playCheckPointSound
  })

end

---禁用当前节的机关
function SectorManager:DeactiveCurrentSector()  
  local sector = GamePlay.GamePlayManager.CurrentSector
  if sector > 0 then
    local s = self.CurrentLevelSectors[sector]
    for _, value in pairs(s.moduls) do
      if value ~= nil then
        value:Deactive()
        value:Reset('sectorRestart')
      end
    end 
  end

  --调试信息
  if BALLANCE_DEBUG then 
    GameUI.GamePlayUI._DebugStatValues['Sector'].Value = sector..'(Deactive)/'..self.CurrentLevelSectorCount
    GameUI.GamePlayUI._DebugStatValues['Moduls'].Value = '0'
  end

  Log.D(TAG, 'Deactive current sector '..sector)

  self.EventSectorDeactive:Emit({ 
    oldSector = sector 
  })
end
---重置当前节的机关
---@param active boolean 重置机关后是否重新激活
function SectorManager:ResetCurrentSector(active)  
  self:DeactiveCurrentSector()
  if active then
    self:ActiveCurrentSector(false)
  end
end
---重置所有机关
---@param active boolean 重置机关后是否重新激活
function SectorManager:ResetAllSector(active) 
  --通知每个modul卸载
  for _, value in pairs(Game.LevelBuilder._CurrentLevelModuls) do
    if value ~= nil then
      value.modul:Deactive()
      value.modul:Reset('levelRestart')
      if active then value.modul:Active() end
    end
  end
  self.CurrentLevelEndBalloon:Reset()

  Log.D(TAG, 'Reset all sector')

  self.EventSectorDeactive:Emit({ 
    active = active 
  })
end

function CreateClass:SectorManager() 
  return SectorManager()
end