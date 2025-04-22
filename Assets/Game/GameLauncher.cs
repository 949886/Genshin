using System;
using System.Collections;
using System.Threading.Tasks;
using Cysharp.Threading.Tasks;
using Luna;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceProviders;

public class GameLauncher : MonoBehaviour
{
    async void Start()
    {
        // var loadOperation = Addressables.LoadSceneAsync("Assets/Modules/World/World Partition.unity", LoadSceneMode.Additive);
        // var loadOperation = Addressables.LoadSceneAsync("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity");
        // LoadScene("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity");
        // Download("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity");
        // StartCoroutine(LoadSceneCoroutine("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity"));
        
        // var handle = Download("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity");
        // StartCoroutine(ProgressCoroutine(handle));
        // await handle.Task;
        // await UniTask.Delay(5000);
        // Debug.Log("Loading scene...");
        // Assets.LoadScene("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity");
        
        var asset = new Asset<SceneInstance>("Assets/Game/World/Teyvat/Mondstadt/Mondstadt for Nahida.unity");
        asset.onProgress += (progress) => {
            Debug.Log($"[Assets] Loading {asset.Address}: {progress * 100}%");
        };
        asset.onDownload += status => {
            Debug.Log($"[Assets] Downloading {asset.Address}: {status.Percent * 100}%");
        };
        var scene = await asset.Load();
    }
    
    // Update is called once per frame
    void Update()
    {
        
    }
    
    private IEnumerator LoadSceneCoroutine(string label)
    {
        var handle = Addressables.LoadSceneAsync(label);
        while (!handle.GetDownloadStatus().IsDone)
        {
            Debug.Log($"Loading {label}: {handle.GetDownloadStatus().Percent * 100}%");
            
            yield return null;
        }
        Debug.Log($"Loading {label}: 100%");
    }
    
    private IEnumerator ProgressCoroutine(AsyncOperationHandle handle)
    {
        while (!handle.GetDownloadStatus().IsDone)
        {
            Debug.Log($"Download {handle.ToString()}: {handle.GetDownloadStatus().Percent * 100}%");
            yield return null;
        }
        Debug.Log($"Download {handle.ToString()}: 100%");
    }

    public AsyncOperationHandle Download(string label, Action<float> progress = null)
    {
        var key = label;
            
        var handle = Addressables.DownloadDependenciesAsync(label);
        handle.Completed += op => {
            if (op.Status == AsyncOperationStatus.Succeeded)
                Debug.Log($"[Assets] Download {label} successfully.");
            else Debug.Log($"[Assets] Downloading {label} failed.");
        };
        
        return handle;
    }

    // public async Task<SceneInstance> LoadScene(string label, Action<float> progress = null)
    // {
    //     var key = label;
    //         
    //     var handle = Addressables.LoadSceneAsync(label);
    //     handle.Completed += op => {
    //         Debug.Log($"[Assets] Loaded scene: {op.Result}");
    //         
    //     };
    //         
    //     UniTask.Void(async () =>
    //     {
    //         while (!handle.IsDone)
    //         {
    //             var status = handle.GetDownloadStatus();
    //             progress?.Invoke(handle.PercentComplete);
    //             Debug.Log($"[Assets] Loading {label}: {status.Percent * 100}%");
    //             await UniTask.Yield();
    //         }
    //         Debug.Log($"[Assets] Loading {label}: 100%");
    //     });
    //         
    //     return await handle.Task;
    // }
}
