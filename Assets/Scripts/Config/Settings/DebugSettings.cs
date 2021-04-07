#if UNITY_EDITOR
using System;
using UnityEditor;
#endif
using UnityEngine;

/*
* Copyright (c) 2020  mengyu
* 
* ģ������ 
* DebugSettings.cs
* 
* ��;��
* ��ȡ�������á�
* �������Unity�༭���е�� Ballance/��������/Debug Settings �˵��������Լ��Ŀ������á�
* 
* ���ߣ�
* mengyu
* 
* ������ʷ��
* 2020-6-12 ����
* 
*/

namespace Ballance2.Config.Settings
{
	/// <summary>
	/// ��������
	/// </summary>
	public class DebugSettings : ScriptableObject
	{
		[Tooltip("���� Ballance ������� ����ģ����ļ���·��")]
		public string DebugFolder = "";
		[Tooltip("�����Ƿ�����System���Բ���")]
		public bool EnableSystemDebugTests = true;
		[Tooltip("����ϵͳ��ʼ���ļ����ط�ʽ")]
		public LoadResWay SystemInitLoadWay = LoadResWay.InDebugFolder;
		[Tooltip("����ģ���ļ����ط�ʽ")]
		public LoadResWay PackageLoadWay = LoadResWay.InDebugFolder;

		private static DebugSettings _instance = null;

		/// <summary>
		/// ��ȡ��������ʵ��
		/// </summary>
		public static DebugSettings Instance
		{
			get
			{
				if (_instance == null)
				{
					_instance = Resources.Load<DebugSettings>("DebugSettings");
#if UNITY_EDITOR
					if (_instance == null)
					{
						_instance = CreateInstance<DebugSettings>();
						try
						{
							AssetDatabase.CreateAsset(_instance, "Assets/Resources/DebugSettings.asset");
						}
						catch(Exception e)
						{
							Debug.LogError("CreateInstance DebugSetting.asset failed!" + e.Message + "\n\n" + e.ToString());
						}
					}
#endif
				}
				return _instance;
			}
		}

#if UNITY_EDITOR 
		[MenuItem("Ballance/����/��������", priority = 298)]
		public static void Open()
		{
			Selection.activeObject = Instance;
		}
#endif

	}

	public enum LoadResWay
    {
		InDebugFolder,
		InUnityEditorProject,
    }
}