---@gendoc

local KeyCode = UnityEngine.KeyCode
local Log = Ballance2.Log
local KeyListener = Ballance2.Services.InputManager.KeyListener
local ObjectStateBackupUtils = Ballance2.Utils.ObjectStateBackupUtils
local Vector3 = UnityEngine.Vector3
local ConstraintSource = UnityEngine.Animations.ConstraintSource
local GameSettingsManager = Ballance2.Services.GameSettingsManager
local GameErrorChecker = Ballance2.Services.Debug.GameErrorChecker
local GameManager = Ballance2.Services.GameManager
local GameError = Ballance2.Services.Debug.GameError
local LuaUtils = Ballance2.Utils.LuaUtils
local DebugUtils = Ballance2.Utils.DebugUtils
local SmoothFly = Ballance2.Game.Utils.SmoothFly
local SpeedMeter = Ballance2.Game.SpeedMeter
local GameLuaObjectHost = Ballance2.Services.LuaService.LuaWapper.GameLuaObjectHost
local Rect = UnityEngine.Rect

---球推动定义
---@class BallPushType
BallPushType = {
  None = 0,--无推动
  Forward = 0x2,-- 前
  Back = 0x4,-- 后
  Left = 0x8,--左 
  Right = 0x10,-- 右
  Up = 0x20, -- 上升
  Down = 0x40, -- 下降
}

---指定球的控制状态
---@class BallControlStatus
BallControlStatus = {
  ---没有控制（无控制、无物理效果，无摄像机跟随）
  NoControl = 0,
  ---正常控制（可控制、物理效果，摄像机跟随）
  Control = 1,
  ---释放模式（例如球坠落，球仍然有物理效果，但无法控制，摄像机不跟随，但看着球）
  UnleashingMode = 2,
  ---锁定模式（例如变换球时，无物理效果，无法控制，但摄像机跟随）
  LockMode = 3,
  ---释放模式2（球仍然有物理效果，但无法控制，摄像机跟随看着球）
  FreeMode = 4,
  ---无物理效果，无法控制，但摄像机不跟随，但看着球
  LockLookMode = 5,
}

---球注册信息存储结构
---@class BallRegStorage
local BallRegStorage = {
  name = '', --球名称
  ball = nil, ---@type Ball 球类实例
  rigidbody = nil, ---@type PhysicsObject 球的刚体实例, 仅当前球激活时才有此实例
  pushForceX = nil, ---@type PhysicsConstantForceData 球的X轴推动力, 仅当前球激活时才有此实例
  pushForceY = nil, ---@type PhysicsConstantForceData 球的Y轴推动力, 仅当前球激活时才有此实例
  pushForceZ = nil, ---@type PhysicsConstantForceData 球的Z轴推动力, 仅当前球激活时才有此实例
  speedMeter = nil, ---@type SpeedMeter 球的速度计
}

---球管理器，负责管理球的注册、运动控制、特殊效果等等。
---@class BallManager : GameLuaObjectHostClass
---@field _BallLightningSphere GameLuaObjectHost
---@field _BallWood GameObject
---@field _BallStone GameObject
---@field _BallPaper GameObject
---@field _BallSmoke GameObject
---@field _BallShadowProjector ParentConstraint
---@field CurrentBallName string 获取当前的球名称 [R]
---@field CurrentBall Ball 获取当前的球 [R]
---@field PushType number 获取或者设置当前球的推动方向 [RW]
---@field CanControll boolean 获取或者设置当前用户是否可以控制球 [RW]
---@field CanControllCamera boolean 获取或者设置当前用户是否可以控制摄像机 [RW]
---@field ShiftPressed boolean 获取当前用户是否按下Shift键 [R]
---@field PosFrame Transform 获取当前球的位置变换实例 [R]
---@field KeyStateUp boolean 获取上升按键状态 [RW]
---@field KeyStateDown boolean 获取下降按键状态 [RW]
---@field KeyStateForward boolean 获取前进按键状态 [RW]
---@field KeyStateBack boolean 获取后退按键状态 [RW]
---@field KeyStateLeft boolean 获取左按键状态 [RW]
---@field KeyStateRight boolean 获取右按键状态 [RW]
---@field BallSpeedFactor number 球速度倍数，默认1 [RW]
BallManager = ClassicObject:extend()

local TAG = 'BallManager'

function BallManager:new()
  self.PushType = 0
  self.CurrentBall = nil
  self.CurrentBallName = ''
  self.CanControll = false
  self.CanControllCamera = false
  self.BallSpeedFactor = 1
  self.ShiftPressed = false
  self._DebugMode = false
  self._private = {
    BallLightningSphere = nil, ---@type BallLightningSphere
    GameSettings = nil, ---@type GameSettingsActuator
    settingsCallbackId = 0,
    controllingStatus = BallControlStatus.NoControl, ---当前状态
    lastSaveLinearVelocity = nil, ---@type Vector3
    lastSaveAngularVelocity = nil, ---@type Vector3
    reverseControl = false, ---是否反向控制
    ---已注册的球
    registerBalls = {}, ---@type BallRegStorage[] 
    ---当前激活的球
    currentBall = nil, ---@type BallRegStorage 
    currentActiveBall = nil, ---@type BallRegStorage 
    keyListener = nil, ---@type KeyListener
    ---控制按键设置
    keySets = {
      keyFront = KeyCode.UpArrow,
      keyBack = KeyCode.DownArrow,
      keyLeft = KeyCode.LeftArrow,
      keyRight = KeyCode.RightArrow,
      keyUpCamera = KeyCode.Space,
      keyRoateCamera = KeyCode.LeftShift,
      keyFront2 = KeyCode.W,
      keyBack2 = KeyCode.S,
      keyLeft2 = KeyCode.A,
      keyRight2 = KeyCode.D,
      keyRoateCamera2 = KeyCode.RightShift,
      keyUp = KeyCode.Q,
      keyDown = KeyCode.E,
    }, 
    nextRecoverPos = Vector3.zero, ---@type Vector3
    rect = Rect(20,100,200,20),
  }
end

function BallManager:Awake()
  GamePlay.BallManager = self
  self._private.BallLightningSphere = self._BallLightningSphere:GetLuaClass()

  --注册事件
  local events = Game.Mediator:RegisterEventEmitter('BallManager')
  self.EventBallRegistered = events:RegisterEvent('BallRegistered') --新球注册事件
  self.EventBallUnRegister = events:RegisterEvent('BallUnRegister') --球删除注册事件
  self.EventCurrentBallChanged = events:RegisterEvent('CurrentBallChanged') --当前球变化事件
  self.EventNextRecoverPosChanged = events:RegisterEvent('NextRecoverPosChanged') --球的下一个出生位置变化事件
  self.EventControllingStatusChanged = events:RegisterEvent('ControllingStatusChanged') --球控制状态变化事件
  self.EventPlaySmoke = events:RegisterEvent('PlaySmoke') --播放烟雾事件
  self.EventPlayLighting = events:RegisterEvent('PlayLighting') --播放闪电事件
  self.EventFlushBallPush = events:RegisterEvent('FlushBallPush') --刷新球推动力状态事件
  self.EventSetBallPushValue = events:RegisterEvent('SetBallPushValue') --球推动力数值手动更新事件
  self.EventRemoveAllBallPush = events:RegisterEvent('RemoveAllBallPush') --清除球推动力事件

  --注册内置球
  self:RegisterBall('BallWood', self._BallWood)
  self:RegisterBall('BallStone', self._BallStone)
  self:RegisterBall('BallPaper', self._BallPaper)

  --初始化控制设置
  local GameSettings = GameSettingsManager.GetSettings("core")
  self._private.settingsCallbackId = GameSettings:RegisterSettingsUpdateCallback("control", function () 
    self:_OnControlSettingsChanged() 
    return false
  end)
  self._private.GameSettings = GameSettings
  self._DebugMode = GameManager.DebugMode
  self.PosFrame = GamePlay.CamManager._CamOrientTransform

  --初始化键盘侦听
  self._private.keyListener = KeyListener.Get(self.gameObject)
  --请求触发设置更新函数
  GameSettings:RequireSettingsLoad("control")

  --注册调试命令
  self._private.CommandId = Game.Manager.GameDebugCommandServer:RegisterCommand('balls', function (eyword, fullCmd, argsCount, args)
    local type = args[1]
    if type == 'play-lighting' then
      self:PlayLighting(self._private.nextRecoverPos, true, true, nil)
    elseif type == 'set-recover-pos' then
      local ox, nx = DebugUtils.CheckIntDebugParam(1, args, Slua.out, true, 0)
      if not ox then return false end
      local oy, ny = DebugUtils.CheckIntDebugParam(2, args, Slua.out, true, 0)
      if not oy then return false end
      local oz, nz = DebugUtils.CheckIntDebugParam(3, args, Slua.out, true, 0)
      if not oz then return false end

      local pos = Vector3(nx, ny, nz)
      self:SetNextRecoverPos(pos)
      Log.D(TAG, 'NextRecoverPos now is : {0}', pos)
    elseif type == 'set-ball' then
      local o, n = DebugUtils.CheckDebugParam(1, args, Slua.out, true, 1)
      if not o then return false end

      self:SetCurrentBall(n)
      Log.D(TAG, 'Set ball type to : {0}', n)

    elseif type == 'set-control-status' then
      local o, n = DebugUtils.CheckIntDebugParam(1, args, Slua.out, true, 1)
      if not o then return false end

      self:SetControllingStatus(n)
      Log.D(TAG, 'Set control status to : {0}', n)
    end
    return true
  end, 1, "balls <next/set/reset/reset-all> 球管理器命令"..
          "  set-recover-pos <x:number> <y:number> <z:number> ▶ 设置下次球激活位置"..
          "  set-ball <ballName:string>                       ▶ 设置当前激活球"..
          "  set-control-status <status:number>               ▶ 设置当前控制模式 status: 0 无控制 1 正常控制 2 释放模式 3 锁定模式 4 释放模式2"..
          "  play-lighting                                    ▶ 播放出生动画"
  )
end
function BallManager:OnDestroy()
  Game.Mediator:UnRegisterEventEmitter('BallManager')
  Game.Manager.GameDebugCommandServer:UnRegisterCommand(self._private.CommandId)

  --清除碎片的定时器
  for _, value in pairs(self._private.registerBalls) do
    if value and value.ball._PiecesData then
      local data = value.ball._PiecesData
      if data.delayHideTimerID then
        LuaTimer.Delete(data.delayHideTimerID)
        data.delayHideTimerID = nil
      end
      if data.fadeOutTimerID then
        LuaTimer.Delete(data.fadeOutTimerID)
        data.fadeOutTimerID = nil
      end
    end
  end

  self._private.registerBalls = {}
  self._private.GameSettings:UnRegisterSettingsUpdateCallback(self._private.settingsCallbackId)
  self._private.keyListener:ClearKeyListen()
end

--#region 球基础控制方法

---注册球 
---@param name string 球名称
---@param gameObject GameObject 球游戏对象，必须已经添加到场景中
function BallManager:RegisterBall(name, gameObject)

  --检查是否注册
  if(self:GetRegisterBall(name) ~= nil) then
    GameErrorChecker.SetLastErrorAndLog(GameError.AlreadyRegistered, TAG, 'Ball {0} already registered', { name })
    return
  end

  --添加刚体组件
  local body = gameObject:AddComponent(BallancePhysics.Wapper.PhysicsObject) ---@type PhysicsObject
  --查找物理参数
  local physicsData = GamePhysBall[name]
  if(physicsData == nil) then
    GameErrorChecker.SetLastErrorAndLog(GameError.ParamNotFound, TAG, 'Not fuoud GamePhysBall data for Ball {0} , please add it before call RegisterBall', { name })
    return
  end
  body.DoNotAutoCreateAtAwake = true
  --设置物理参数
  body.Fixed = false
  body.Mass = physicsData.Mass
  if physicsData.BallRadius > 0 then
    body.UseBall = true
    body.BallRadius = physicsData.BallRadius
  else
    body.UseBall = false
  end
  body.Friction = physicsData.Friction
  body.Elasticity = physicsData.Elasticity
  body.RotSpeedDamping = physicsData.RotDamp
  body.LinearSpeedDamping = physicsData.LinearDamp
  body.Layer = physicsData.Layer
  body.EnableCollision = true
  body.AutoControlActive = false
  body.AutoMassCenter = false
  body.UseExistsSurface = true

  --设置恒力
  body.EnableConstantForce = true

  --添加速度计
  local speedMeter = gameObject:GetComponent(SpeedMeter) ---@type SpeedMeter
  if(speedMeter == nil) then
    speedMeter = gameObject:AddComponent(SpeedMeter)
    speedMeter.Enabled = true
  end

  local gameLuaObjectHost = gameObject:GetComponent(GameLuaObjectHost) ---@type GameLuaObjectHost
  if(gameLuaObjectHost == nil) then
    gameLuaObjectHost = gameObject:AddComponent(GameLuaObjectHost) ---@type GameLuaObjectHost
  end
  local ball = gameLuaObjectHost:CreateClass() ---@type Ball
  if(ball == nil) then
    GameErrorChecker.SetLastErrorAndLog(GameError.ClassNotFound, TAG, 'Not found Ball class on {0} !', { name })
    return
  end

  local pieces = ball:GetPieces()
  --设置球相关物理参数
  ball._PiecesPhysicsData = physicsData.PiecesPhysicsData
  --设置推动物理参数
  ball._PiecesMinForce = physicsData.PiecesMinForce
  ball._PiecesMaxForce = physicsData.PiecesMaxForce
  ball._Force = physicsData.Force
  ball._UpForce = physicsData.UpForce * 1.5
  ball._DownForce = physicsData.DownForce
  if(pieces ~= nil) then
    ObjectStateBackupUtils.BackUpObjectAndChilds(pieces) --备份碎片的状态
  end

  --还需要设置一个Unity的碰撞器，用于死亡区的检测
  local collder = gameObject:AddComponent(UnityEngine.SphereCollider) ---@type SphereCollider
  collder.radius = physicsData.TiggerBallRadius or 2
  local rigidbody = gameObject:AddComponent(UnityEngine.Rigidbody) ---@type Rigidbody
  rigidbody.isKinematic = true
  rigidbody.useGravity = false

  --设置名称
  if(gameObject.name ~= name) then gameObject.name = name end

  self.EventBallRegistered:Emit({
    ball = ball, 
    body = body, 
    speedMeter = speedMeter
  })

  table.insert(self._private.registerBalls, {
    name = name,
    ball = ball,
    rigidbody = body,
    speedMeter = speedMeter
  })

  --初始化球声音
  self:_InitBallSounds(ball, speedMeter, body)
end
---取消注册球 
---@param name string 球名称
function BallManager:UnRegisterBall(name)
  local registerBalls = self._private.registerBalls
  for i = 1, #registerBalls do  
    local ball = registerBalls[i]
    if(ball.name == name) then
      if ball == self._private.currentActiveBall then
        self:_DeactiveCurrentBall()
      end
      self:_UnInitBallSounds(ball.rigidbody, ball.speedMeter)
      table.remove(registerBalls, i)

      self.EventBallUnRegister:Emit(name)
      return true
    end 
  end 
  GameErrorChecker.SetLastErrorAndLog(GameError.NotRegister, TAG, 'Ball {0} not register', { name })
  return false
end
---获取注册了的球 
---@param name string 球名称
function BallManager:GetRegisterBall(name)
  local registerBalls = self._private.registerBalls
  for i = 1, #registerBalls do  
    if(registerBalls[i].name == name) then
      return registerBalls[i]
    end 
  end
end
---获取当前激活的球
function BallManager:GetCurrentBall() return self._private.currentBall end
---设置当前正在控制的球 
---@param name string 球名称，不可为空
---@param status number|nil 同时设置新的控制状态, 如果为空，则保持之前的控制状态
function BallManager:SetCurrentBall(name, status)
  if(name == nil or name == '') then
    GameErrorChecker.SetLastErrorAndLog(GameError.NotRegister, TAG, 'You must provide a name for the ball')
  end
  local ball = self:GetRegisterBall(name)
  if(ball == nil) then
    GameErrorChecker.SetLastErrorAndLog(GameError.NotRegister, TAG, 'Ball {0} not register', { name })
    return
  end
  if(self._private.currentBall ~= ball) then
    self:_DeactiveCurrentBall()
    self._private.currentBall = ball
    self.CurrentBall = ball.ball
    self.CurrentBallName = ball.name
    self.EventCurrentBallChanged:Emit(name)
    self:SetControllingStatus(status)
  end
end
---设置禁用当前正在控制的球
function BallManager:SetNoCurrentBall()
  self.EventCurrentBallChanged:Emit('')
  self:_DeactiveCurrentBall()
end
---设置当前球的控制的状态
---@param status number|nil 新的状态值（@see BallControlStatus）,为 nil 时不改变状态只刷新
function BallManager:SetControllingStatus(status)
  if(status ~= nil) then 
    self._private.controllingStatus = status
    self:_FlushCurrentBallAllStatus()
  elseif(status ~= self._private.controllingStatus) then
    self:_FlushCurrentBallAllStatus()
  end
end
---设置下一次球出生位置
---@param pos Vector3|nil 出生位置，如果不填，则自动设置为当前球位置
function BallManager:SetNextRecoverPos(pos)
  --自动设置为当前球位置
  if pos == nil then
    local current = self._private.currentActiveBall
    if current ~= nil then
      pos = current.ball.transform.position
    end
  end

  self.EventNextRecoverPosChanged:Emit(pos)
  self._private.nextRecoverPos = pos
end
---重置指定球的碎片
---@param typeName string 球名称，不可为空
function BallManager:ResetPeices(typeName)
  local ball = self:GetRegisterBall(typeName)
  if ball ~= nil then
    ball.ball:ResetPieces()
  else
    Log.W(TAG, 'Ball type '..typeName..' not found')
  end
end
---抛出指定球的碎片
---@param typeName string 球名称，不可为空
function BallManager:ThrowPeices(typeName, pos)
  local ball = self:GetRegisterBall(typeName)
  if ball ~= nil then
    ball.ball:ThrowPieces(pos or self._private.nextRecoverPos) 
  else
    Log.W(TAG, 'Ball type '..typeName..' not found')
  end
end
---恢复摄像机相关移动
function BallManager:StartCamMove()
  if GamePlay.CamManager.Target == nil then
    GamePlay.CamManager:SetTarget(self._private.currentBall.ball.transform, true)
  end
end
---停止摄像机相关移动
function BallManager:StopCamMove()
  if GamePlay.CamManager.Target ~= nil then
    GamePlay.CamManager:SetTarget(nil)
  end
end

  --#region 球状态工作方法

function BallManager:_FlushCurrentBallAllStatus() 
  local SetDebugStatus = function (stat)
    --调试信息
    if BALLANCE_DEBUG then GameUI.GamePlayUI._DebugStatValues['CurrentStatus'].Value = stat end
  end

  local status = self._private.controllingStatus
  if status == BallControlStatus.NoControl then
    self:_SetCanControl(false)
    self.CanControllCamera = false
    self:_DeactiveCurrentBall()
    GamePlay.CamManager:DisbleAll()
    SetDebugStatus('NoControl')
  elseif status == BallControlStatus.Control then
    self:_SetCanControl(true)
    self.CanControllCamera = true
    self:_ActiveCurrentBall()
    self:_PhysicsOrDePhysicsCurrentBall(true)
    GamePlay.CamManager:SetCamLook(true):SetCamFollow(true)
    SetDebugStatus('Control')
  elseif status == BallControlStatus.LockMode then
    self:_SetCanControl(false)
    self.CanControllCamera = true
    self:_ActiveCurrentBall()
    self:_PhysicsOrDePhysicsCurrentBall(false)
    GamePlay.CamManager:SetCamLook(true):SetCamFollow(true)
    SetDebugStatus('LockMode')
  elseif status == BallControlStatus.UnleashingMode then
    self:_SetCanControl(false)
    self.CanControllCamera = true
    self:_ActiveCurrentBall()
    self:_PhysicsOrDePhysicsCurrentBall(true)
    GamePlay.CamManager:SetCamLook(true):SetCamFollow(false)
    SetDebugStatus('UnleashingMode')
  elseif status == BallControlStatus.FreeMode then
    self:_SetCanControl(false)
    self.CanControllCamera = true
    self:_ActiveCurrentBall()
    self:_PhysicsOrDePhysicsCurrentBall(true)
    GamePlay.CamManager:SetCamLook(true):SetCamFollow(true)
    SetDebugStatus('FreeMode')
  elseif status == BallControlStatus.LockLookMode then
    self:_SetCanControl(false)
    self.CanControllCamera = false
    self:_ActiveCurrentBall()
    self:_PhysicsOrDePhysicsCurrentBall(false)
    GamePlay.CamManager:SetCamLook(true):SetCamFollow(false)
    SetDebugStatus('LockLookMode')
  end

  self.EventControllingStatusChanged:Emit(nil)
end
function BallManager:_SetCanControl(can) 
  self.CanControll = can
end
---取消激活当前的球
function BallManager:_DeactiveCurrentBall() 
  local current = self._private.currentActiveBall
  if current ~= nil then
    --隐藏阴影
    self._BallShadowProjector.constraintActive = false
    if self._BallShadowProjector.gameObject.activeSelf then
      self._BallShadowProjector.gameObject:SetActive(false)
    end
    --清除力
    self:RemoveAllBallPush()
    --取消激活
    if current.rigidbody.IsPhysicalized then
      self:_PhysicsOrDePhysicsCurrentBall(false)
    end
    current.ball.gameObject:SetActive(false)
    --清空摄像机跟随对象
    GamePlay.CamManager:SetTarget(nil)
    self._private.currentActiveBall = nil
  end
  if BALLANCE_DEBUG then 
    GameUI.GamePlayUI._DebugStatValues['CurrentBall'].Value = 'None' 
    --删除定时器
    if self._private.debugFlushInfoTimer then
      LuaTimer.Delete(self._private.debugFlushInfoTimer)
      self._private.debugFlushInfoTimer = nil
    end
  end
end
function BallManager:_ActiveCurrentBall() 
  local current = self._private.currentActiveBall ---@type BallRegStorage
  if current == nil and self._private.currentBall ~= nil then
    current = self._private.currentBall---@type BallRegStorage
    local currentTransform = current.ball.transform
    self._private.currentActiveBall = self._private.currentBall
    --设置阴影位置与父级约束    
    local constraintSource = ConstraintSource()
    constraintSource.sourceTransform = currentTransform
    constraintSource.weight = 1
    self._BallShadowProjector:SetSource(0, constraintSource)
    self._BallShadowProjector.constraintActive = true
    --显示阴影
    if not self._BallShadowProjector.gameObject.activeSelf then
      self._BallShadowProjector.gameObject:SetActive(true)
    end
    ---设置位置
    currentTransform.position = self._private.nextRecoverPos
    --设置摄像机跟随对象
    GamePlay.CamManager:SetTarget(currentTransform)
    --清除力
    self:RemoveAllBallPush()
    --调试信息
    if BALLANCE_DEBUG then 
      GameUI.GamePlayUI._DebugStatValues['CurrentBall'].Value = current.name 
      local Position = GameUI.GamePlayUI._DebugStatValues['Position']
      local Rotation = GameUI.GamePlayUI._DebugStatValues['Rotation']
      local Velocity = GameUI.GamePlayUI._DebugStatValues['Velocity']
      local PushValue = GameUI.GamePlayUI._DebugStatValues['PushValue']
      local PhysicsTime = GameUI.GamePlayUI._DebugStatValues['PhysicsTime']
      local PhysicsObjects = GameUI.GamePlayUI._DebugStatValues['PhysicsObjects']
      local PhysicsState = GameUI.GamePlayUI._DebugStatValues['PhysicsState'];
      local GamePhysicsWorld = GamePlay.GamePlayManager.GamePhysicsWorld
      
      --删除定时器
      if self._private.debugFlushInfoTimer then
        LuaTimer.Delete(self._private.debugFlushInfoTimer)
        self._private.debugFlushInfoTimer = nil
      end
      --每秒更新球位置调试显示数据
      self._private.debugFlushInfoTimer = LuaTimer.Add(500, 500, function ()

        if not Game.Manager.GameSettings:GetBool('debugDisableBallInfo', false) then
          --球位置
          Position:SetVector3Value(currentTransform.position)
          Rotation:SetVector3Value(currentTransform.rotation)
        end
        if not Game.Manager.GameSettings:GetBool('debugDisablePhysicsInfo', false) then
          --物理时间
          PhysicsTime.Value = string.format("%.2f ms / %.3f s", GamePhysicsWorld.PhysicsTime * 1000, GamePhysicsWorld.PhysicsSimuateTime)
          --物理对象信息
          PhysicsObjects.Value = string.format("All/Active/Update %d/%d/%d\nFixed/FallCollect/Push %d/%d/%d", 
            GamePhysicsWorld.PhysicsBodies, 
            GamePhysicsWorld.PhysicsActiveBodies, 
            GamePhysicsWorld.PhysicsUpdateBodies,
            GamePhysicsWorld.PhysicsFixedBodies,
            GamePhysicsWorld.PhysicsFallCollectBodies, 
            GamePhysicsWorld.PhysicsConstantPushBodies
          )
        end

        if not Game.Manager.GameSettings:GetBool('debugDisableBallInfo', false) then
          --球的速度和推动数据
          if current.rigidbody.IsPhysicalized then
            PhysicsState.Value = string.format("%.2f", current.speedMeter.NowAbsoluteSpeed)
              .. ' ContractState: ' .. current.rigidbody.ContractCacheString
              ..current.ball._SoundManagerDebugStrings

            Velocity:SetVector3Value(current.rigidbody.SpeedVector)
            PushValue.Value = '('..string.format("%.2f", current.pushForceX.Force) 
              ..', '..string.format("%.2f", current.pushForceY.Force)
              ..', '..string.format("%.2f", current.pushForceZ.Force)..')'
          else
            PhysicsState.Value = ''
            PushValue.Value = ''
            Velocity.Value = ''
          end
        end
      end)
    end

  end
end
---@param physics boolean
function BallManager:_PhysicsOrDePhysicsCurrentBall(physics) 
  local current = self._private.currentActiveBall
  if current ~= nil then
    --激活
    local physicsed = current.rigidbody.IsPhysicalized
    current.ball.gameObject:SetActive(true)
    if physics and not physicsed then
      current.rigidbody:Physicalize() 
      current.rigidbody:ClearConstantForce()
      current.rigidbody:WakeUp()
      --添加球的xyz推动恒力
      current.pushForceX = current.rigidbody:AddConstantForceWithPositionAndRef(0, Vector3.right, Vector3.zero, GamePlay.CamManager.CamDirectionRef, current.ball.transform)
      current.pushForceZ = current.rigidbody:AddConstantForceWithPositionAndRef(0, Vector3.forward, Vector3.zero, GamePlay.CamManager.CamDirectionRef, current.ball.transform)
      current.pushForceY = current.rigidbody:AddConstantForceWithPositionAndRef(0, Vector3.up, Vector3.zero, GamePlay.CamManager.CamDirectionRef, current.ball.transform)
      --激活
      current.ball:Active()
      --启动球的声音
      GamePlay.BallSoundManager:AddSoundableBall(current)
      --取消推动
      self:RemoveAllBallPush()
      --需要重新发送按键状态，因为可能在变球时用户还是按住按键，而此时球已经切换了，球的恒力需要重新设置
      self._private.keyListener:ReSendPressingKey()
    end
    if not physics and physicsed then
      --取消推动
      self:RemoveAllBallPush()
      --停止球的声音
      GamePlay.BallSoundManager:RemoveSoundableBall(current)
      --移除球的推动恒力
      if current.pushForceX then
        current.pushForceX:Delete()
        current.pushForceX = nil
      end
      if current.pushForceZ then
        current.pushForceZ:Delete()
        current.pushFpushForceZorceY = nil
      end
      if current.pushForceY then
        current.pushForceY:Delete()
        current.pushForceY = nil
      end
      --取消激活
      current.ball:Deactive()
      current.rigidbody:UnPhysicalize(true)
    end
  end
end

  --#endregion

--#endregion

--#region 球附加工具方法

---播放球出生时的烟雾
---@param pos Vector3 放置位置
function BallManager:PlaySmoke(pos)
  self._BallSmoke.transform.position = pos
  self._BallSmoke:SetActive(true)
  self.EventPlaySmoke:Emit(nil)
end
---播放球出生时的闪电效果
---@param pos Vector3 放置位置
---@param smallToBig boolean 是否由小到大
---@param lightAnim boolean 是否同时播放灯光效果
---@param callback function 播放完成后，会调用这个完成回调
function BallManager:PlayLighting(pos, smallToBig, lightAnim, callback) 
  self.EventPlayLighting:Emit(nil)
  self._private.BallLightningSphere:PlayLighting(pos, smallToBig, lightAnim, callback)
end
---获取当前是否正在运行球出生闪电效果
---@return boolean
function BallManager:IsLighting() 
  return self._private.BallLightningSphere:IsLighting()
end
---快速将球锁定并移动至目标位置
---@param pos Vector3 目标位置
---@param time number 时间 (秒)
---@param callback function 移动完成后会调用此回调
function BallManager:FastMoveTo(pos, time, callback)

  --锁定
  self:SetControllingStatus(BallControlStatus.LockMode)

  if self._private.currentActiveBall ~= nil then  
    local ball = self._private.currentActiveBall.ball
    local mover = ball.gameObject:GetComponent(SmoothFly) ---@type SmoothFly
    if mover == nil then
      mover = ball.gameObject:AddComponent(SmoothFly) ---@type SmoothFly
    end

    mover.TargetPos = pos
    mover.Time = time
    mover.ArrivalDiatance = 0.02
    mover.StopWhenArrival = true
    mover.ArrivalCallback = callback
    mover.Fly = true
  end
end

--#endregion

--#region 键盘设置与初始化

function BallManager:_InitKeyEvents()
  --添加按键事件
  local keyListener = self._private.keyListener
  local keySets = self._private.keySets
  keyListener:ClearKeyListen()
  keyListener:AddKeyListen(keySets.keyFront, function (key, down) self:_UpArrow_Key(key, down) end)
  keyListener:AddKeyListen(keySets.keyBack, function (key, down) self:_DownArrow_Key(key, down) end)
  keyListener:AddKeyListen(keySets.keyUp, function (key, down) self:_Up_Key(key, down) end)
  keyListener:AddKeyListen(keySets.keyDown, function (key, down) self:_Down_Key(key, down) end)
  keyListener:AddKeyListen(keySets.keyUpCamera, function (key, down) self:_Space_Key(key, down)  end)
  keyListener:AddKeyListen(keySets.keyRoateCamera, function (key, down) self:_Shift_Key(key, down)  end)
  keyListener:AddKeyListen(keySets.keyLeft, function (key, down) self:_LeftArrow_Key(key, down) end)
  keyListener:AddKeyListen(keySets.keyRight, function (key, down) self:_RightArrow_Key(key, down) end)

  --测试按扭
  if self._DebugMode then
    self._private.keyListener:AddKeyListen(KeyCode.Alpha1, function (key, downed)
      if(downed) then
        self:SetNextRecoverPos()
        self:SetCurrentBall('BallWood', BallControlStatus.Control)
      end
    end)
    self._private.keyListener:AddKeyListen(KeyCode.Alpha2, function (key, downed)
      if(downed) then
        self:SetCurrentBall('BallStone', BallControlStatus.Control)
      end
    end)
    self._private.keyListener:AddKeyListen(KeyCode.Alpha3, function (key, downed)
      if(downed) then
        self:SetCurrentBall('BallPaper', BallControlStatus.Control)
      end
    end)
    self._private.keyListener:AddKeyListen(KeyCode.Alpha4, function (key, downed)
      if(downed) then
        GamePlay.GamePlayManager:_Rebirth()
      end
    end)  
    self._private.keyListener:AddKeyListen(KeyCode.Alpha5, function (key, downed)
      if(downed) then
        GamePlay.GamePlayManager:AddLife()
      end
    end)    
    self._private.keyListener:AddKeyListen(KeyCode.Alpha6, function (key, downed)
      if(downed) then
        GamePlay.GamePlayManager:Fall()
      end
    end)
    self._private.keyListener:AddKeyListen(KeyCode.Alpha7, function (key, downed)
      if(downed) then
        if(downed) then
          self:SetControllingStatus(BallControlStatus.NoControl)
          self:SetNextRecoverPos(Vector3.zero)
        end
      end
    end)   
  end
end
function BallManager:_OnControlSettingsChanged()
  --当设置更改时或加载时，更新设置到当前变量
  local GameSettings = self._private.GameSettings
  local keySets = self._private.keySets
  keySets.keyFront = GameSettings:GetInt("control.key.front", KeyCode.UpArrow)
  keySets.keyUp = GameSettings:GetInt("control.key.up", KeyCode.Q)
  keySets.keyDown = GameSettings:GetInt("control.key.down", KeyCode.E)
  keySets.keyBack = GameSettings:GetInt("control.key.back", KeyCode.DownArrow)
  keySets.keyLeft = GameSettings:GetInt("control.key.left", KeyCode.LeftArrow)
  keySets.keyRight = GameSettings:GetInt("control.key.right", KeyCode.RightArrow)
  keySets.keyRoateCamera = GameSettings:GetInt("control.key.roate", KeyCode.LeftShift)
  keySets.keyRoateCamera2 = GameSettings:GetInt("control.key.roate2", KeyCode.RightShift)
  keySets.keyUpCamera = GameSettings:GetInt("control.key.up_cam", KeyCode.Space)

  self._private.reverseControl = GameSettings:GetBool("control.reverse", false)
  self:_InitKeyEvents()
end

--#endregion

--#region 键盘事件处理

function BallManager:_UpArrow_Key(key, down)
  self.KeyStateForward = down
  self:FlushBallPush()
end
function BallManager:_DownArrow_Key(key, down)
  self.KeyStateBack = down
  self:FlushBallPush()
end
function BallManager:_RightArrow_Key(key, down)
  self._RightPressed = down
  if (down) then
    --旋转摄像机
    if (self.CanControllCamera and self.ShiftPressed) then
      if(self._private.reverseControl) then
        GamePlay.CamManager:RotateLeft()
      else
        GamePlay.CamManager:RotateRight()
      end
      --按下shift时不许推动
      self.KeyStateRight = false
    else
      self.KeyStateRight = true
    end
    self:FlushBallPush()
  else
    self.KeyStateRight = false
    self:FlushBallPush()
  end
end
function BallManager:_LeftArrow_Key(key, down)
  self._LeftPressed = down
  if (down) then
    --旋转摄像机
    if (self.CanControllCamera and self.ShiftPressed) then
      if(self._private.reverseControl) then
        GamePlay.CamManager:RotateRight()
      else
        GamePlay.CamManager:RotateLeft()
      end
      --按下shift时不许推动
      self.KeyStateLeft = false
    else
      --
      self.KeyStateLeft = true
    end
    self:FlushBallPush()
  else
    self.KeyStateLeft = false
    self:FlushBallPush()
  end
end
function BallManager:_Down_Key(key, down)
  if (self._DebugMode) then
    self.KeyStateDown = down
    self:FlushBallPush()
  end
end
function BallManager:_Up_Key(key, down)
  if (self._DebugMode) then
    self.KeyStateUp = down
    self:FlushBallPush()
  end
end
function BallManager:_Space_Key(key, down) 
  if (self.CanControllCamera) then
    GamePlay.CamManager:RotateUp(down) 
  end
end
function BallManager:_Shift_Key(key, down) 
  self.ShiftPressed = down
  if self._LeftPressed then
    --旋转摄像机
    if (down and self.CanControllCamera) then
      if(self._private.reverseControl) then
        GamePlay.CamManager:RotateRight()
      else
        GamePlay.CamManager:RotateLeft()
      end
      --禁用左推动
      self.KeyStateLeft = false
    else
      --抬起时重新恢复左推动
      self.KeyStateLeft = true
    end
    self:FlushBallPush()
  elseif self._RightPressed then
    --旋转摄像机
    if (down and self.CanControllCamera) then
      if(self._private.reverseControl) then
        GamePlay.CamManager:RotateLeft()
      else
        GamePlay.CamManager:RotateRight()
      end
      --禁用右推动
      self.KeyStateRight = false
    else
      --抬起时重新恢复右推动
      self.KeyStateRight = true
    end
    self:FlushBallPush()
  end
end

--#endregion

--#region 推动方法

---刷新球推动方向按键
function BallManager:FlushBallPush()
  if self.CurrentBall == nil or self._private.currentActiveBall == nil or not self.CanControll then
    return
  end
  local currentBall = self._private.currentActiveBall
  local force = self.CurrentBall._Force * self.BallSpeedFactor

  --前进后退
  if self.KeyStateForward and self.KeyStateBack then
    currentBall.pushForceZ.Force = 0
  elseif self.KeyStateForward then
    currentBall.pushForceZ.Force = force
  elseif self.KeyStateBack then
    currentBall.pushForceZ.Force = -force
  else
    currentBall.pushForceZ.Force = 0
  end
  --左右
  if self.KeyStateLeft and self.KeyStateRight then
    currentBall.pushForceX.Force = 0
  elseif self.KeyStateLeft then
    currentBall.pushForceX.Force = -force
  elseif self.KeyStateRight then
    currentBall.pushForceX.Force = force
  else
    currentBall.pushForceX.Force = 0
  end
  --上下
  if self.KeyStateUp and self.KeyStateDown then
    currentBall.pushForceY.Force = 0
  elseif self.KeyStateUp then
    currentBall.pushForceY.Force = currentBall.ball._UpForce
  elseif self.KeyStateDown then
    currentBall.pushForceY.Force = -currentBall.ball._DownForce
  else
    currentBall.pushForceY.Force = 0
  end

  self.EventFlushBallPush:Emit(nil)
end
---设置球推动方向数值，此函数可以用于摇杆控制
---@param x number X轴推动力百分比（[-1,1]）
---@param y number Y轴推动力百分比（[-1,1]）
function BallManager:SetBallPushValue(x, y)
  if self.CurrentBall == nil or self._private.currentActiveBall == nil or not self.CanControll then
    return
  end
  local currentBall = self._private.currentActiveBall
  local force = self.CurrentBall._Force
  self.EventSetBallPushValue:Emit({x, y})
  currentBall.pushForceX.Force = x * force
  currentBall.pushForceZ.Force = y * force
end
---去除当前球所有推动方向
function BallManager:RemoveAllBallPush()
  if self.CurrentBall == nil or self._private.currentActiveBall == nil or not self.CanControll then
    return
  end
  local currentBall = self._private.currentActiveBall
  self.EventRemoveAllBallPush:Emit(nil)

  if currentBall.pushForceX then currentBall.pushForceX.Force = 0 end
  if currentBall.pushForceY then currentBall.pushForceY.Force = 0 end
  if currentBall.pushForceZ then currentBall.pushForceZ.Force = 0 end
end

--#endregion

--#region 球声音方法

---初始化球声音相关事件处理函数
---@param ball Ball
---@param speedMeter SpeedMeter
---@param body PhysicsObject
function BallManager:_InitBallSounds(ball, speedMeter, body)
  speedMeter.Enabled = true
  speedMeter.Callback = function ()
    GamePlay.BallSoundManager:HandlerBallRollSpeedChange(ball, speedMeter)
  end
  body.EnableCollisionEvent = true
end

---删除球声音相关事件处理函数
---@param body PhysicsObject
---@param speedMeter SpeedMeter
function BallManager:_UnInitBallSounds(body, speedMeter)
  speedMeter.Enabled = false
  speedMeter.Callback = nil
  body.EnableCollisionEvent = false
end

--#endregion


function CreateClass:BallManager()
  return BallManager() 
end