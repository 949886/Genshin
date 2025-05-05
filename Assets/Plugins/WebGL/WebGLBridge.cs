// Created by LunarEclipse on 2025-04-28 16:04.

using System.Runtime.InteropServices;

namespace Plugins.WebGL
{
    public class WebGLBridge 
    {
        [DllImport("__Internal")] public static extern void Hello();
        [DllImport("__Internal")] public static extern void PrintArray(float[] array, int size);
        [DllImport("__Internal")] public static extern string Echo(string str);  
        [DllImport("__Internal")] public static extern int AddNumbers(int x, int y);
    }
}