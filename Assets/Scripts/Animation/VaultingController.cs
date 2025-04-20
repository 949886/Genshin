using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VaultingController : MonoBehaviour
{
    protected Animator animator;
    public Transform target;

    
    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        // If there is a object in front of the player, the player will vault over it 
        if (Physics.Raycast(transform.position, transform.TransformDirection(Vector3.forward), out RaycastHit hit, 2))
        {
            if (hit.transform.tag == "Vaultable")
            {
                animator.SetBool("Vault", true);
                target = hit.transform;
            }
        }

        // Match the player's left hand to the target's position
        if (animator.GetBool("Vault"))
        {
            animator.MatchTarget(target.position, target.rotation, AvatarTarget.LeftHand, new MatchTargetWeightMask(Vector3.one, 1), 0.1f, 0.5f);
        }
        
    }
}
