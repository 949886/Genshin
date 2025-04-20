//UNITY_SHADER_NO_UPGRADE
#ifndef MYHLSLINCLUDE_INCLUDED
#define MYHLSLINCLUDE_INCLUDED

void MyFunction_float(float3 A, float B, UnityTexture2D C, out float3 Out)
{
    Out = A + B;
}
#endif //MYHLSLINCLUDE_INCLUDED