// SPDX-License-Identifier: (Not available for this version, you are only allowed to use this software if you have express permission from the copyright holder and agreed to the latest NiloToonURP EULA)
// Copyright (c) 2021 Kuroneko ShaderLab Limited

// For more information, visit -> https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample

// #pragma once is a safe guard best practice in almost every .hlsl, 
// doing this can make sure your .hlsl's user can include this .hlsl anywhere anytime without producing any multi include conflict
#pragma once

float3 ConvertNormalTSToNormalTargetSpace(float3 normalTS, float3 tangentTargetSpace, float3 bitangentTargetSpace, float3 normalTargetSpace)
{
    // TBN matrix, usually when you need to convert tangent space normal to other space, you will need a TBN matrix of that space
    float3x3 TBNMatrixTargetSpace = float3x3(tangentTargetSpace, bitangentTargetSpace, normalTargetSpace);
   
    // Usually 99% of the time you will see hlsl's mul() in this order
    // result = mul(matrix, vector)

    // However doing the multiplication of the matrix and the vector in a different order; the matrix is transposed.
    // mul(matrix, vector) == mul(vector, transpose(matrix))
    // mul(transpose(matrix), vector) == mul(vector, matrix)

    // for more information about it you can read: https://forum.unity.com/threads/mul-function-and-matrices.445266/#post-2880535

    // 1.TBNMatrixTargetSpace is a rotation only 3x3 matrix
    // 2.The inverse of a rotation only matrix is its transpose, which is also a rotation only matrix
    // (https://en.wikipedia.org/wiki/Rotation_matrix)
    // 3.mul(A,B) is the transpose of mul(B,A)
    float3 newNormalTargetSpace = mul(normalTS, TBNMatrixTargetSpace); // so this line means transform from Tangent space back to TargetSpace 

    return newNormalTargetSpace;
}

