using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateAroundY : MonoBehaviour
{
    public bool aroundWorldSpace = true;
    public float speed = 45f;
    
    // Update is called once per frame
    void Update()
    {
        transform.RotateAround(transform.position, aroundWorldSpace?  Vector3.up : transform.up, Time.deltaTime * speed);
    }
}
