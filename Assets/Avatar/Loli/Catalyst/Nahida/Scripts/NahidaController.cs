using Avatar.Loli.Catalyst.Nahida;
using Avatar.Loli.Catalyst.Nahida.Scripts;
using Luna.Core.Locomotion.Character;
using UnityEngine;

namespace GI
{
    public class NahidaController : ThirdPersonCharacterController
    {
        [Header("Nahida")]
        public Animator swingAnimator;
        public NahidaSwingShader swingShader;
        
        private NahidAnimationStateController _animationStateController;
        private float _idleTime = 0f;
        
        protected override void Start()
        {
            base.Start();
            
            _animationStateController = _animator.GetBehaviour<NahidAnimationStateController>();
            _animationStateController.onStateChange += OnAnimationStateChange;
        }

        private void OnAnimationStateChange(NahidAnimationStateController.AnimationState state)
        {
            if (state != NahidAnimationStateController.AnimationState.Show)
            {
                HideSwing();
            }
        }

        protected override void Update()
        {
            base.Update();
            
            // Idle Time
            if (IsIdle)
                _idleTime += Time.deltaTime;
            else _idleTime = 0f;

            // Swing Animation
            if (_idleTime > 3f)
            {
                ShowSwing();
            }
        }

        public void ShowSwing()
        {
            _animator.SetInteger("Show" ,1);
            swingAnimator.gameObject.SetActive(true);
        }
        
        public void HideSwing()
        {
            _animator.SetInteger("Show" ,0);
            swingAnimator.gameObject.SetActive(false);
        }
    }
}