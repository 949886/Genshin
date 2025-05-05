// // Created by LunarEclipse on 2025-04-27 14:04.

using System;
using Luna.Core.Animation;
using Luna.Core.Locomotion.Character;
using Luna.Extensions.Unity;
using UnityEngine;

namespace Avatar.Loli.Catalyst.Nahida.Scripts
{
    public class NahidAnimationStateController : ThirdPersonCharacterAttackBehaviour
    {
        public AnimationState State { get; private set; } = AnimationState.Idle;
        public AnimationState PreviousState { get; private set; } = AnimationState.Idle;
        
        /// Triggered when the animation state changes.
        ///
        /// Parameters:
        ///     - AnimationState: current animation state
        public event Action<AnimationState> onStateChange;
        
        public override void OnAnimationStart(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        {
            base.OnAnimationStart(animator, stateInfo, layerIndex);
            
            if (layerIndex == 0)
            {
                var stateName = animator.GetCurrentStateName(layerIndex);
                Debug.Log($"[NahidAnimationStateController] Animation Start: {stateName} {layerIndex} {this.ToString()}");
                
                if (stateInfo.IsTag("Show") || stateName.StartsWith("Show."))
                    State = AnimationState.Show;
                else State = AnimationState.Idle;

                if (State != PreviousState)
                {
                    onStateChange?.Invoke(State);
                    PreviousState = State;
                }
            }
        }

        // public override void OnAnimationExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationEnd(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationFinish(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationUpdate(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationInterrupt(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationTransitionInStart(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationTransitionInEnd(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationTransitionOutStart(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        //
        // public override void OnAnimationTransitionOutEnd(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        // {
        //     
        // }
        
        [Serializable]
        public enum AnimationState
        {
            Idle,
            Walk,
            Run,
            Jump,
            Fall,
            Show,
            Swim,
            SwimIdle,
            SwimWalk,
            SwimRun,
            SwimJump,
            SwimFall,
            SwimLand,
        }
    }
}