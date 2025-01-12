﻿using Ballance2.Entry;
using Ballance2.Services.LuaService.Lua;
using Ballance2.UI.CoreUI;
using Ballance2.Utils;
using SLua;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

/*
* Copyright(c) 2021  mengyu
*
* 模块名：     
* GameErrorChecker.cs
* 
* 用途：
* 错误检查器。
* 使用错误检查器获取游戏API的调用错误。
* 错误检查器还可负责弹出全局错误窗口以检查BUG.
*
* 作者：
* mengyu
*/

namespace Ballance2.Services.Debug
{
  /// <summary>
  /// 错误检查器
  /// </summary>
  [SLua.CustomLuaClass]
  [LuaApiDescription("错误检查器")]
  [LuaApiNotes(@"使用错误检查器获取游戏API的调用错误。

错误检查器还可负责弹出全局错误窗口以检查BUG.")]
  public class GameErrorChecker
  {
    private static GameGlobalErrorUI gameGlobalErrorUI;
    private static List<string> gameErrorLogPools;
    private static int gameErrorLogObserver = 0;

    internal static void SetGameErrorUI(GameGlobalErrorUI errorUI)
    {
      gameGlobalErrorUI = errorUI;
    }

    /// <summary>
    /// 抛出游戏异常，此操作会直接停止游戏。类似于 Windows 蓝屏功能。
    /// </summary>
    /// <param name="code">错误代码</param>
    /// <param name="message">关于错误的异常信息</param>
    [LuaApiDescription("抛出游戏异常，此操作会直接停止游戏。类似于 Windows 蓝屏功能。")]
    [LuaApiParamDescription("code", "错误代码")]
    [LuaApiParamDescription("message", "关于错误的异常信息")]
    public static void ThrowGameError(GameError code, string message)
    {
      StringBuilder stringBuilder = new StringBuilder("错误代码：");
      stringBuilder.Append(code.ToString());
      stringBuilder.Append("\n");
      stringBuilder.Append(string.IsNullOrEmpty(message) ? GameErrorInfo.GetErrorMessage(code) : message);
      stringBuilder.Append("\n");
      stringBuilder.Append(DebugUtils.GetStackTrace(1));
      stringBuilder.Append("\n");

      if(gameErrorLogPools != null && gameErrorLogPools.Count > 0) {
        stringBuilder.Append("Errors:\n");
        foreach (var item in gameErrorLogPools)
        {
          stringBuilder.Append(item);
          stringBuilder.Append("\n");
        }
      }

      GameSystem.ForceInterruptGame();
      HideInternalObjects();
      gameGlobalErrorUI.ShowErrorUI(stringBuilder.ToString());
      UnityEngine.Debug.LogError(stringBuilder.ToString());
    }

    /// <summary>
    /// 获取或设置上一个操作的错误
    /// </summary>
    [LuaApiDescription("获取或设置上一个操作的错误")]
    public static GameError LastError { get; set; }
    /// <summary>
    /// 获取上一个操作的错误说明文字
    /// </summary>
    /// <returns></returns>
    [LuaApiDescription("获取上一个操作的错误说明文字")]
    public static string GetLastErrorMessage()
    {
      return GameErrorInfo.GetErrorMessage(LastError);
    }

    private static int StrictModeStack = 0;

    /// <summary>
    /// 获取当前是否是严格模式
    /// </summary>
    /// <value></value>
    [LuaApiDescription("获取当前是否是严格模式")]
    public static bool StrictMode { get; private set; }
    /// <summary>
    /// 进入严格模式。严格模式中如果Lua代码出现异常，则将立即弹出错误提示并停止游戏。
    /// </summary>
    [LuaApiDescription("进入严格模式。严格模式中如果Lua代码出现异常，则将立即弹出错误提示并停止游戏。")]
    public static void EnterStrictMode()
    {
      StrictModeStack++;
      StrictMode = true;
    }
    /// <summary>
    /// 退出严格模式
    /// </summary>
    [LuaApiDescription("退出严格模式")]
    public static void QuitStrictMode()
    {
      if(StrictModeStack > 0)
        StrictModeStack--;
      StrictMode = StrictModeStack == 0;
    }

    internal static void LuaStateErrReport(LuaState state, string err) {
      if(StrictMode) 
      {
        //尝试分析，如果错误是运行内核包发出，则显示带报错的代码，否则显示普通错误对话框
        var fileName = LuaUtils.GetLuaCallerFileName(state.L);
        var packName = LuaGlobalApi.PackageNameByLuaFilePath(fileName);
        if(packName == GamePackageManager.CORE_PACKAGE_NAME || packName == GamePackageManager.SYSTEM_PACKAGE_NAME) {
          string errDetail = string.Format("Lua代码异常：\n发生错误的文件：{0} 模块：{1}\n",fileName, packName) + err;
          ThrowGameError(GameError.ExecutionFailed, errDetail);
        }
        else 
          ShowScriptErrorMessage(fileName, packName, err);
      } 
      else Log.E("LuaState", err);
    }
    internal static void Init() {
      gameErrorLogPools = new List<string>();
      gameErrorLogObserver = Log.RegisterLogObserver(LogObserver, LogLevel.Error | LogLevel.Warning);
    }
    internal static void Destroy() {
      if(gameErrorLogPools != null) {
        gameErrorLogPools.Clear();
        gameErrorLogPools = null;
      }
      if(gameErrorLogObserver > 0) {
        Log.UnRegisterLogObserver(gameErrorLogObserver);
        gameErrorLogObserver = 0;
      }
    }

    private static void LogObserver(LogLevel level, string tag, string message, string stackTrace) {
      if(gameErrorLogPools.Count > 10)
        gameErrorLogPools.RemoveAt(0);
      StringBuilder sb = new StringBuilder();
      sb.Append('[');
      sb.Append(tag);
      sb.Append("] ");
      sb.Append(message);
      sb.Append('\n');
      sb.Append(stackTrace);
      gameErrorLogPools.Add(sb.ToString());
    }

    /// <summary>
    /// 设置错误码并打印日志
    /// </summary>
    /// <param name="code">错误码</param>
    /// <param name="tag">日志标签</param>
    /// <param name="message">日志信息格式化字符串</param>
    /// <param name="param">日志信息格式化参数</param>
    [LuaApiDescription("设置错误码并打印日志")]
    [LuaApiParamDescription("code", "错误代码")]
    [LuaApiParamDescription("tag", "日志标签")]
    [LuaApiParamDescription("message", "日志信息格式化字符串")]
    [LuaApiParamDescription("param", "日志信息格式化参数")]
    public static void SetLastErrorAndLog(GameError code, string tag, string message, params object[] param)
    {
      LastError = code;
      Log.E(tag, message, param);
    }
    /// <summary>
    /// 设置错误码并打印日志
    /// </summary>
    /// <param name="code">错误码</param>
    /// <param name="tag">TAG</param>
    /// <param name="message">错误信息</param>
    [LuaApiDescription("设置错误码并打印日志")]
    [LuaApiParamDescription("code", "错误代码")]
    [LuaApiParamDescription("tag", "日志标签")]
    [LuaApiParamDescription("message", "日志信息")]
    public static void SetLastErrorAndLog(GameError code, string tag, string message)
    {
      LastError = code;
      Log.E(tag, message);
    }

    private static void HideInternalObjects() {
      var GameGlobalMask = GameObject.Find("GameGlobalMask");
      if(GameGlobalMask != null)
        GameGlobalMask.SetActive(false);
      var GameGlobalIngameLoading = GameObject.Find("GameGlobalIngameLoading");
      if(GameGlobalIngameLoading != null)
        GameGlobalIngameLoading.SetActive(false);
    }

    /// <summary>
    /// 显示系统错误信息提示提示对话框
    /// </summary>
    /// <param name="message">错误信息</param>
    [LuaApiDescription("显示系统错误信息提示提示对话框")]
    [LuaApiParamDescription("message", "错误信息")]
    public static void ShowSystemErrorMessage(string message)
    {
      GameEntry entry = GameEntry.Instance;
      if(entry) {
        GameSystem.ForceInterruptGame();
        HideInternalObjects();
        entry.GlobalGameSysErrMessageDebuggerTipDialogText.text = message;
        entry.GlobalGameSysErrMessageDebuggerTipDialog.SetActive(true);
      }
    }
    /// <summary>
    /// 显示脚本错误信息提示提示对话框
    /// </summary>
    /// <param name="message">错误信息</param>
    [LuaApiDescription("显示脚本错误信息提示提示对话框")]
    [LuaApiParamDescription("message", "错误信息")]
    public static void ShowScriptErrorMessage(string fileName, string packName, string message)
    {
      GameEntry entry = GameEntry.Instance;
      if(entry) {
        GameSystem.ForceInterruptGame();
        HideInternalObjects();

        string err = string.Format("Lua代码异常：\n发生错误的文件：{0} 模块：{1}\n",fileName, packName) + message;
        entry.GlobalGameScriptErrDialog.Show(err);
        UnityEngine.Debug.LogError(err);
      }
    }
  }
}
