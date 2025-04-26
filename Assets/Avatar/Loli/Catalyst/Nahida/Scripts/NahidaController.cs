using Avatar.Loli.Catalyst.Nahida;
using Luna.Core.Locomotion.Character;
using UnityEngine;

namespace GI
{
    public class NahidaController : ThirdPersonCharacterController
    {
        [Header("Nahida")]
        public Animator nahidaAnimator;
        public Animator swingAnimator;
        public NahidaSwingShader swingShader;
        
        private float _idleTime = 0f;
        
        protected override void Start()
        {
            base.Start();
            
            nahidaAnimator = GetComponent<Animator>();
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
            nahidaAnimator.SetInteger("Show" ,1);
            swingAnimator.gameObject.SetActive(true);
        }
        
        public void HideSwing()
        {
            nahidaAnimator.SetInteger("Show" ,0);
            swingAnimator.gameObject.SetActive(false);
        }
    }
}