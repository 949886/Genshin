// Created by LunarEclipse on 2024-2-13 17:35.

using System;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using Object = UnityEngine.Object;

namespace Luna.World
{
    public class Chunk
    {
        public readonly float size;
        public readonly GameObject fallback;
        
        public Vector3 Position => GameObject.transform.position;
        
        public Vector3Int Coords { get; private set; }
        public GameObject GameObject { get; private set; }
        public ChunkState State { get; private set; } = ChunkState.Unloaded;

        public Chunk(float size, Vector3Int coords, GameObject fallback = null)
        {
            this.size = size;
            this.Coords = coords;
            this.fallback = fallback;
        }

        public void Unload()
        {
            if (GameObject != null)
            {
                Object.Destroy(GameObject);
                GameObject = null;
                State = ChunkState.Unloaded;
            }
        }
        
        public void Load(Action<GameObject> onLoaded = null)
        {
            if (State == ChunkState.Loaded) return;
            
            var chunkName = $"Chunk_X{Coords.x}_Y{Coords.y}_Z{Coords.z}";
            var handle = Addressables.LoadAssetAsync<GameObject>(chunkName);
            State = ChunkState.Loading;
            handle.Completed += operation =>
            {
                if (operation.Status == AsyncOperationStatus.Succeeded)
                {
                    var prefab = operation.Result;
                    GameObject = Object.Instantiate(prefab, new Vector3(Coords.x * size, Coords.y * size, Coords.z * size), Quaternion.identity);
                    onLoaded?.Invoke(GameObject);
                }
                else
                {
                    Debug.LogWarning($"Failed to load prefab {chunkName}, using fallback prefab instead.");
                    if (fallback == null)
                    {
                        Debug.LogError($"No fallback prefab provided for {chunkName}");
                        return;
                    }
                    GameObject = Object.Instantiate(fallback, new Vector3(Coords.x * size, Coords.y * size, Coords.z * size), Quaternion.identity);
                    onLoaded?.Invoke(GameObject);
                }

                State = ChunkState.Loaded;
            };
        }
        
        public void Reload(Vector3Int coords, Action<GameObject> onLoaded = null)
        {
            Unload();
            Coords = coords;
            Load(onLoaded);
        }

        public enum ChunkState
        {
            Unloaded,
            Loading,
            Loaded,
        }
    }
}