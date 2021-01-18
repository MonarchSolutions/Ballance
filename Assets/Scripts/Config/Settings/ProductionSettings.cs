#if UNITY_EDITOR
using System;
using UnityEditor;
#endif
using UnityEngine;

/*
* Copyright (c) 2020  mengyu
* 
* ģ������ 
* ProductionSettings.cs
* 
* ��;��
* �������þ�̬����
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
	/// �������þ�̬����
	/// </summary>
	public class ProductionSettings : ScriptableObject
	{





		private static ProductionSettings _instance = null;

		/// <summary>
		/// ��ȡ��������ʵ��
		/// </summary>
		public static ProductionSettings Instance
		{
			get
			{
				if (_instance == null)
				{
					_instance = Resources.Load<ProductionSettings>("ProductionSettings");
#if UNITY_EDITOR
					if (_instance == null)
					{
						_instance = CreateInstance<ProductionSettings>();
						try
						{
							AssetDatabase.CreateAsset(_instance, "Assets/Resources/ProductionSettings.asset");
						}
						catch(Exception e)
						{
							Debug.LogError("CreateInstance ProductionSettings.asset failed!" + e.Message + "\n\n" + e.ToString());
						}
					}
#endif
				}
				return _instance;
			}
		}

#if UNITY_EDITOR 
		[MenuItem("Ballance/����/Production Settings", priority = 298)]
		public static void Open()
		{
			Selection.activeObject = Instance;
		}
#endif

	}
}