using UnityEngine;

public partial class Utils
{
    public static Vector3 GetMousePositionInWorld() 
    {
        return GetMousePositionInWorld(Input.mousePosition, Camera.main);
    }
    
    public static Vector3 GetMousePositionInWorld(Vector3 screenPosition, Camera worldCamera) 
    {
        Vector3 worldPosition = worldCamera.ScreenToWorldPoint(screenPosition);
        return worldPosition;
    }
    
}