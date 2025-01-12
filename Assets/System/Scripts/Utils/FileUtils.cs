﻿using System.IO;
using System.Text;
using Ballance2.Services.LuaService;
using UnityEngine;

/*
* Copyright(c) 2021  mengyu
*
* 模块名：     
* FileUtils.cs
* 
* 用途：
* 文件工具类。提供了文件操作相关工具方法。
* 
* Lua 中不允许直接访问文件系统，因此此处提供了一些方法来允许Lua读写本地配置文件,操作或删除本地目录等。
* 但注意，这些API不允许访问用户文件，只允许访问以下目录：
* 游戏主目录（Windows/linux exe同级与子目录）
* Application.dataPath
* Application.persistentDataPath
* Application.temporaryCachePath
* Application.streamingAssetsPath
* 尝试访问不可访问的目录将会抛出异常。
*
* 作者：
* mengyu
*
*/

namespace Ballance2.Utils
{
  /// <summary>
  /// 文件工具类
  /// </summary>
  [SLua.CustomLuaClass]
  [LuaApiDescription("文件工具类")]
  [LuaApiNotes(@"文件工具类。提供了文件操作相关工具方法。

Lua 中不允许直接访问文件系统，因此此处提供了一些方法来允许Lua读写本地配置文件,操作或删除本地目录等。

但注意，这些API不允许访问用户文件，只允许访问以下目录：
* 游戏主目录（Windows/linux exe同级与子目录）
* Application.dataPath
* Application.persistentDataPath
* Application.temporaryCachePath
* Application.streamingAssetsPath

尝试访问不可访问的目录将会抛出异常。
")]
  public class FileUtils
  {
    private static byte[] zipHead = new byte[4] { 0x50, 0x4B, 0x03, 0x04 };
    private static byte[] untyFsHead = new byte[7] { 0x55, 0x6e, 0x69, 0x74, 0x79, 0x46, 0x53 };

    /// <summary>
    /// 检测文件头是不是zip
    /// </summary>
    /// <param name="file">要检测的文件路径</param>
    /// <returns>如果文件头匹配则返回true，否则返回false</returns>
    [LuaApiDescription("检测文件头是不是zip", "如果文件头匹配则返回true，否则返回false")]
    [LuaApiParamDescription("file", "要检测的文件路径")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static bool TestFileIsZip(string file)
    {
      return TestFileHead(file, zipHead);
    }
    /// <summary>
    /// 检测文件头是不是unityFs
    /// </summary>
    /// <param name="file">要检测的文件路径</param>
    /// <returns>如果文件头匹配则返回true，否则返回false</returns>
    [LuaApiDescription("检测文件头是不是unityFs", "如果文件头匹配则返回true，否则返回false")]
    [LuaApiParamDescription("file", "要检测的文件路径")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static bool TestFileIsAssetBundle(string file)
    {
      return TestFileHead(file, untyFsHead);
    }
    /// <summary>
    /// 检测自定义文件头
    /// </summary>
    /// <param name="file">要检测的文件路径</param>
    /// <param name="head">自定义文件头</param>
    /// <returns>如果文件头匹配则返回true，否则返回false</returns>
    [LuaApiDescription("检测自定义文件头", "如果文件头匹配则返回true，否则返回false")]
    [LuaApiParamDescription("file", "要检测的文件路径")]
    [LuaApiParamDescription("head", "自定义文件头")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static bool TestFileHead(string file, byte[] head)
    {
      SecurityUtils.CheckFileAccess(file);
      byte[] temp = new byte[head.Length];
      FileStream fs = new FileStream(PathUtils.FixFilePathScheme(file), FileMode.Open);
      fs.Read(temp, 0, head.Length);
      fs.Close();
      return StringUtils.TestBytesMatch(temp, head);
    }

    [LuaApiDescription("写入字符串至指定文件")]
    [LuaApiParamDescription("path", "文件路径")]
    [LuaApiParamDescription("append", "是否追加写入文件，否则为覆盖写入")]
    [LuaApiParamDescription("data", "要写入的文件")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static void WriteFile(string path, bool append, string data)
    {
      SecurityUtils.CheckFileAccess(path);
      var sw = new StreamWriter(path, append);
      sw.Write(data);
      sw.Close();
      sw.Dispose();
    }

    [LuaApiDescription("检查文件是否存在", "返回文件是否存在")]
    [LuaApiParamDescription("path", "文件路径")]
    public static bool FileExists(string path) { return File.Exists(path); }
    [LuaApiDescription("检查文件是否存在", "返回文件是否存在")]
    [LuaApiParamDescription("path", "文件路径")]
    public static bool DirectoryExists(string path) { return Directory.Exists(path); }
    [LuaApiDescription("创建目录")]
    [LuaApiParamDescription("path", "目录路径")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static void CreateDirectory(string path)
    {
      SecurityUtils.CheckFileAccess(path);
      Directory.CreateDirectory(path);
    }
    [LuaApiDescription("读取文件至字符串", "返回文件内容")]
    [LuaApiParamDescription("path", "文件路径")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static string ReadFile(string path)
    {
      SecurityUtils.CheckFileAccess(path);

      if (!File.Exists(path))
        throw new FileNotFoundException("Cant read non-exists file", path);

      var sr = new StreamReader(path);
      var rs = sr.ReadToEnd();
      sr.Close();
      sr.Dispose();
      return rs;
    }
    /// <summary>
    /// 读取文件所有内容为字节数组
    /// </summary>
    /// <param name="file">文件路径</param>
    /// <remarks>注意：此 API 不能读取用户个人的本地文件。</remarks>
    /// <returns>返回字节数组</returns>
    [LuaApiDescription("读取文件所有内容为字节数组。注意：此 API 不能读取用户个人的本地文件。", "返回字节数组")]
    [LuaApiParamDescription("file", "文件路径")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static byte[] ReadAllToBytes(string file)
    {
      SecurityUtils.CheckFileAccess(file);
      FileStream fs = new FileStream(PathUtils.FixFilePathScheme(file), FileMode.Open);
      byte[] temp = new byte[fs.Length];
      fs.Read(temp, 0, temp.Length);
      fs.Close();
      return temp;
    }
    [LuaApiDescription("删除指定的文件或目录》注意：此 API 不能删除用户个人的本地文件。")]
    [LuaApiParamDescription("path", "文件")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static void RemoveFile(string path)
    {
      SecurityUtils.CheckFileAccess(path);

      if (Directory.Exists(path))
        Directory.Delete(path, true);
      else if (File.Exists(path))
        File.Delete(path);
    }
    [LuaApiDescription("删除指定的目录》注意：此 API 不能删除用户个人的本地文件。")]
    [LuaApiParamDescription("path", "目录的路径")]
    [LuaApiException("FileAccessException", "尝试访问不可访问的目录将会抛出异常。")]
    public static void RemoveDirectory(string path)
    {
      SecurityUtils.CheckFileAccess(path);
      if (Directory.Exists(path))
        Directory.Delete(path, true);
    }
    

    /// <summary>
    /// 把文件大小（字节）按单位转换为可读的字符串
    /// </summary>
    /// <param name="longFileSize">文件大小（字节）</param>
    /// <returns>可读的字符串，例如2.5M</returns>
    [LuaApiDescription("把文件大小（字节）按单位转换为可读的字符串", "可读的字符串，例如2.5M")]
    [LuaApiParamDescription("longFileSize", "文件大小（字节）")]
    public static string GetBetterFileSize(long longFileSize)
    {
      StringBuilder sizeStr = new StringBuilder();
      float fileSize;
      if (longFileSize >= 1073741824)
      {
        fileSize = Mathf.Round(longFileSize / 1073741824 * 100) / 100;
        sizeStr.Append(fileSize);
        sizeStr.Append("G");
      }
      else if (longFileSize >= 1048576)
      {
        fileSize = Mathf.Round(longFileSize / 1048576 * 100) / 100;
        sizeStr.Append(fileSize);
        sizeStr.Append("M");
      }
      else
      {
        fileSize = Mathf.Round(longFileSize / 1024 * 100) / 100;
        sizeStr.Append(fileSize);
        sizeStr.Append("K");
      }
      return sizeStr.ToString();
    }
  }


}
