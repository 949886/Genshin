// Created by LunarEclipse on 2024-2-13 17:35.

using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceLocations;
using Object = UnityEngine.Object;

namespace Luna.World
{
    public class Chunk
    {
        public readonly float size;
        public readonly GameObject fallback;
        
        public Vector3 Position => GameObject != null ? GameObject.transform.position : (Vector3) Coords * size;
        
        public Vector3Int Coords { get; private set; }
        public GameObject GameObject { get; private set; }
        public ChunkState State { get; private set; } = ChunkState.Unloaded;

        private AsyncOperationHandle<IList<IResourceLocation>> _locationsHandle;
        private AsyncOperationHandle<GameObject> _assetHandle;
        private int _loadVersion;

        public Chunk(float size, Vector3Int coords, GameObject fallback = null)
        {
            this.size = size;
            this.Coords = coords;
            this.fallback = fallback;
        }

        public void Unload()
        {
            // Invalidates callbacks from requests that are still in flight.
            _loadVersion++;
            State = ChunkState.Unloaded;
            if (GameObject != null)
            {
                Object.Destroy(GameObject);
                GameObject = null;
            }

            if (_locationsHandle.IsValid()) Addressables.Release(_locationsHandle);
            _locationsHandle = default;
            if (_assetHandle.IsValid()) Addressables.Release(_assetHandle);
            _assetHandle = default;
        }
        
        public void Load(Action<GameObject> onLoaded = null)
        {
            if (State != ChunkState.Unloaded) return;
            
            var chunkName = $"Chunk_X{Coords.x}_Y{Coords.y}_Z{Coords.z}";
            var loadVersion = ++_loadVersion;
            State = ChunkState.Loading;

            // Missing cells are normal in a sparse world. A location lookup returns
            // an empty list instead of raising InvalidKeyException for these cells.
            _locationsHandle = Addressables.LoadResourceLocationsAsync(chunkName, typeof(GameObject));
            _locationsHandle.Completed += locations =>
            {
                if (loadVersion != _loadVersion) return;

                IResourceLocation location = null;
                if (locations.Status == AsyncOperationStatus.Succeeded)
                {
                    if (locations.Result.Count > 0) location = locations.Result[0];
                }
                else
                {
                    Debug.LogWarning($"Failed to locate {chunkName}: {locations.OperationException}");
                }

                Addressables.Release(locations);
                _locationsHandle = default;

                if (location == null)
                {
                    InstantiateChunk(fallback, onLoaded);
                    return;
                }

                _assetHandle = Addressables.LoadAssetAsync<GameObject>(location);
                _assetHandle.Completed += operation =>
                {
                    if (loadVersion != _loadVersion) return;

                    if (operation.Status == AsyncOperationStatus.Succeeded && operation.Result != null)
                    {
                        InstantiateChunk(operation.Result, onLoaded);
                    }
                    else
                    {
                        Debug.LogWarning($"Failed to load prefab {chunkName}, using fallback prefab instead.");
                        Addressables.Release(operation);
                        _assetHandle = default;
                        InstantiateChunk(fallback, onLoaded);
                    }
                };
            };
        }

        private void InstantiateChunk(GameObject prefab, Action<GameObject> onLoaded)
        {
            if (prefab == null)
            {
                State = ChunkState.Empty;
                return;
            }

            GameObject = Object.Instantiate(prefab, (Vector3) Coords * size, Quaternion.identity);
            State = ChunkState.Loaded;
            onLoaded?.Invoke(GameObject);
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
            Empty,
        }
    }
}
