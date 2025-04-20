/* 
    ------------------- Code Monkey -------------------

    Thank you for downloading this package
    I hope you find it useful in your projects
    If you have any questions let me know
    Cheers!

               unitycodemonkey.com
    --------------------------------------------------
 */

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Testing : MonoBehaviour {

    private GridWidget grid;
    private float mouseMoveTimer;
    private float mouseMoveTimerMax = .01f;

    private void Start() {
        grid = new GridWidget(100, 100, 1f, new Vector3(0, 0));

        // HeatMapVisual heatMapVisual = new HeatMapVisual(grid, GetComponent<MeshFilter>());
    }

    private void Update() {
        HandleClickToModifyGrid();
        // HandleHeatMapMouseMove();

        if (Input.GetMouseButtonDown(1)) {
            Debug.Log(grid.GetValue(Utils.GetMousePositionInWorld()));
        }
    }

    private void HandleClickToModifyGrid() {
        if (Input.GetMouseButtonDown(0)) {
            grid.SetValue(Utils.GetMousePositionInWorld(), 1);
        }
    }

    private void HandleHeatMapMouseMove() {
        mouseMoveTimer -= Time.deltaTime;
        if (mouseMoveTimer < 0f) {
            mouseMoveTimer += mouseMoveTimerMax;
            int gridValue = grid.GetValue(Utils.GetMousePositionInWorld());
            grid.SetValue(Utils.GetMousePositionInWorld(), gridValue + 1);
        }
    }
    
}
