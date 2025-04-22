// Created by LunarEclipse on 2024-2-19 10:32.

#if UNITY_2019_3_OR_NEWER

using Luna.Extensions;
using UnityEngine;

namespace Luna.World
{
    public class WorldRenderer : MonoBehaviour
    {
        public GameObject fallback; // Fallback prefab to use if the chunk cannot be loaded
        public GameObject player;
        [Range(16, 256)] public int chunkSize = 16;
        
        public int renderDistance = 2;
        private int renderSize => 2 * renderDistance + 1;
        
        
        private Chunk[,,] _chunks;
        
        private Vector3Int _lastPlayerChunk;
        
        private void Start()
        {
            _chunks = new Chunk[renderSize, renderSize, renderSize];
            _lastPlayerChunk = Vector3Int.zero;
            
            for (var i = 0; i < renderSize; i++)
                for (var j = 0; j < renderSize; j++)
                    for (var k = 0; k < renderSize; k++)
                    {
                        var coords = new Vector3Int(
                            i - renderDistance, 
                            j - renderDistance,
                            k - renderDistance);
                        
                        Debug.Log($"Creating chunk at {coords}");
                        var chunk = new Chunk(chunkSize, coords, fallback);
                        _chunks[i, j, k] = chunk;
                        chunk.Load(go => {
                            go.transform.parent = transform;
                        });
                    }
        }

        private void Update()
        {
            var playerPosition = player.transform.position;
            var playerChunk = new Vector3Int((int) playerPosition.x / chunkSize, (int) playerPosition.y / chunkSize, (int) playerPosition.z / chunkSize);
            if (playerChunk != _lastPlayerChunk)
            {
                _lastPlayerChunk = playerChunk;
                UpdateChunks(playerChunk);
            }
        }

        private void UpdateChunks(Vector3Int playerChunk)
        {
            Debug.Log($"Updating chunks at {playerChunk}");
            for (var i = 0; i < renderSize; i++)
                for (var j = 0; j < renderSize; j++)
                    for (var k = 0; k < renderSize; k++)
                    {
                        var coords = new Vector3Int(
                            playerChunk.x + i - renderDistance,
                            playerChunk.y + j - renderDistance,
                            playerChunk.z + k - renderDistance);
                        
                        // Destroy the chunk if it's outside the render distance
                        var chunk = _chunks[(i + playerChunk.x).Mod(renderSize), (j + playerChunk.y).Mod(renderSize), (k + playerChunk.z).Mod(renderSize)];
                        if (chunk.State != Chunk.ChunkState.Loaded) continue;
                        if (Mathf.Abs(playerChunk.x - chunk.Coords.x) > renderDistance ||
                            Mathf.Abs(playerChunk.y - chunk.Coords.y) > renderDistance ||
                            Mathf.Abs(playerChunk.z - chunk.Coords.z) > renderDistance)
                            chunk.Reload(coords,go => {
                                go.transform.parent = transform;
                            });
                    }
        }
    }
}

#endif