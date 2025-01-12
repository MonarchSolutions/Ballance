
--[[
Copyright(c) 2021  mengyu
* 模块名：     
Entry.lua
* 用途：
主菜单进入入口
* 作者：
mengyu
]]--

local GameManager = Ballance2.Services.GameManager
local GamePackage = Ballance2.Package.GamePackage
local Log = Ballance2.Log
local GameMenuLevel = nil
local GameUIManager = GameManager.GetSystemService('GameUIManager') ---@type GameUIManager
local CloneUtils = Ballance2.Utils.CloneUtils
local GameEventNames = Ballance2.Base.GameEventNames

local WaitForSeconds = UnityEngine.WaitForSeconds
local Yield = UnityEngine.Yield

local GameMenuLevelEnterHandler = nil
local GameMenuLevelQuitHandler = nil

---进入MenuLevel场景
---@param thisGamePackage GamePackage
local function OnEnterMenuLevel(thisGamePackage)
  Log.D(thisGamePackage.TAG, 'Enter menuLevel')

  GameManager.Instance:SetGameBaseCameraVisible(false)

  if(GameMenuLevel == nil) then
    GameMenuLevel = CloneUtils.CloneNewObject(thisGamePackage:GetPrefabAsset('GameMenuLevel.prefab'), 'GameMenuLevel')
  end

  if not GameMenuLevel.activeSelf then
    GameMenuLevel:SetActive(true)
  end

  coroutine.resume(coroutine.create(function ()
    Yield(WaitForSeconds(0.5))
    GameUIManager:GoPage('PageMain')
    Yield(WaitForSeconds(1))
    GameUIManager:MaskBlackFadeOut(1)
  end))
end
---退出MenuLevel场景
---@param thisGamePackage GamePackage
local function OnQuitMenuLevel(thisGamePackage)
  Log.D(thisGamePackage.TAG, 'Quit menuLevel')

  GameUIManager:CloseAllPage()

  if (not Slua.IsNull(GameMenuLevel)) then 
    GameMenuLevel:SetActive(false)
  end 
  
  GameManager.Instance:SetGameBaseCameraVisible(true)
end

return {
  Init = function ()
    local thisGamePackage = GamePackage.GetCorePackage()
    GameMenuLevelPackage = thisGamePackage
    GameMenuLevelEnterHandler = GameManager.GameMediator:RegisterEventHandler(thisGamePackage, GameEventNames.EVENT_LOGIC_SECNSE_ENTER, "Intro", function (evtName, params)
      local scense = params[1]
      if(scense == 'MenuLevel') then OnEnterMenuLevel(thisGamePackage) end
      return false
    end)    
    GameMenuLevelQuitHandler = GameManager.GameMediator:RegisterEventHandler(thisGamePackage, GameEventNames.EVENT_LOGIC_SECNSE_QUIT, "Intro", function (evtName, params)
      local scense = params[1]
      if(scense == 'MenuLevel') then OnQuitMenuLevel(thisGamePackage) end
      return false
    end)
  end,
  Unload = function ()
    if (not Slua.IsNull(GameMenuLevel)) then UnityEngine.Object.Destroy(GameMenuLevel) end 
    GameManager.GameMediator:UnRegisterEventHandler(GameEventNames.EVENT_LOGIC_SECNSE_ENTER, GameMenuLevelEnterHandler)
    GameManager.GameMediator:UnRegisterEventHandler(GameEventNames.EVENT_LOGIC_SECNSE_QUIT, GameMenuLevelQuitHandler)
  end
}