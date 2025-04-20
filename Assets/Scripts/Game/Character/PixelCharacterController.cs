using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PixelCharacterController : MonoBehaviour
{
    public float movementSpeed = 1f;

    private Animator animator;
    private int lastDirection;

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void FixedUpdate()
    {
        float horizontalInput = Input.GetAxis("Horizontal");
        float verticalInput = Input.GetAxis("Vertical");

        Vector2 inputVector = new Vector2(horizontalInput, verticalInput);
        inputVector = Vector2.ClampMagnitude(inputVector, 1);
        Vector2 movement = inputVector * movementSpeed;
//        Vector2 newPos = currentPos + movement * Time.fixedDeltaTime;

        SetDirection(movement);
    }

    public void SetDirection(Vector2 direction)
    {
        if (direction.magnitude > .01f)
            lastDirection = DirectionToIndex(direction, 8);

        animator.SetFloat("Direction", lastDirection);
    }

    //this function converts a Vector2 direction to an index to a slice around a circle
    //this goes in a counter-clockwise direction.
    public static int DirectionToIndex(Vector2 dir, int sliceCount)
    {
        Vector2 normDir = dir.normalized;
        float step = 360f / sliceCount;
        float angle = Vector2.SignedAngle(Vector2.down, normDir);
        if (angle < 0)
            angle += 360;
        float stepCount = angle / step + 0.5F;
        return Mathf.FloorToInt(stepCount);
    }
}
