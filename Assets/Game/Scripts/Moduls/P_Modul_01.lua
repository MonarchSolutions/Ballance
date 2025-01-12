local ObjectStateBackupUtils = Ballance2.Utils.ObjectStateBackupUtils

---P_Modul_01
---栅栏机关
---@class P_Modul_01 : ModulBase
---@field P_Modul_01_Rinne PhysicsObject
---@field P_Modul_01_Filter PhysicsObject
---@field P_Modul_01_Pusher PhysicsObject
P_Modul_01 = ModulBase:extend()

function P_Modul_01:new()
  P_Modul_01.super.new(self)
end
function P_Modul_01:Start()
  if not self.IsPreviewMode then
    self.P_Modul_01_Pusher.CollisionID = GamePlay.BallSoundManager:GetSoundCollIDByName('WoodOnlyHit')
  end
end
function P_Modul_01:Active()
  self.gameObject:SetActive(true)
  self.P_Modul_01_Rinne.gameObject:SetActive(true)
  self.P_Modul_01_Filter.gameObject:SetActive(true)
  self.P_Modul_01_Pusher.gameObject:SetActive(true)
  self.P_Modul_01_Rinne:Physicalize()
  self.P_Modul_01_Filter:Physicalize()
  self.P_Modul_01_Pusher:Physicalize()
end
function P_Modul_01:Deactive()
  self.P_Modul_01_Rinne:UnPhysicalize(true)
  self.P_Modul_01_Filter:UnPhysicalize(true)
  self.P_Modul_01_Pusher:UnPhysicalize(true)
  self.gameObject:SetActive(false)
end
function P_Modul_01:Reset()
  ObjectStateBackupUtils.RestoreObjectAndChilds(self.gameObject)
end
function P_Modul_01:Backup()
  ObjectStateBackupUtils.BackUpObjectAndChilds(self.gameObject)
end

function P_Modul_01:ActiveForPreview()
  self.gameObject:SetActive(true)
end
function P_Modul_01:DeactiveForPreview()
  self.gameObject:SetActive(false)
end

function CreateClass:P_Modul_01()
  return P_Modul_01()
end