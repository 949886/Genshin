using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateAroundAxis : MonoBehaviour
{
    [HeaderAttribute ("RotateAround")]
    public bool x = true;
    public bool y = false;
    public bool z = false;

    [HeaderAttribute ("Roration Space")]
    public bool aroundWorldSpace = true;
    // Update is called once per frame

    [HeaderAttribute ("Angular Velocity"), TooltipAttribute("Angle rotated in one second.")]
    public float speed = 360;

    void Update()
    {
        if (x) transform.RotateAround(transform.position, aroundWorldSpace?  Vector3.right : transform.right, Time.deltaTime * speed);
        if (y) transform.RotateAround(transform.position, aroundWorldSpace?  Vector3.up : transform.up, Time.deltaTime * speed);
        if (z) transform.RotateAround(transform.position, aroundWorldSpace?  Vector3.forward : transform.forward, Time.deltaTime * speed);
    }
}
