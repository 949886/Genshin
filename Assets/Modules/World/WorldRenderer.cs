// Created by LunarEclipse on 2024-2-19 10:32.

#if UNITY_2019_3_OR_NEWER

using UnityEngine;

namespace Luna.World
{
    public class WorldRenderer : MonoBehaviour
    {
        public GameObject fallback; // Fallback prefab to use if the chunk cannot be loaded
        public GameObject player;
        [Range(16, 256)] public int chunkSize = 16;
        
        [Min(0)] public int renderDistance = 2;
        
        
        private Chunk[,,] _chunks;
        
        private Vector3Int _lastPlayerChunk;
        private int _renderDistance;
        private int _chunkSize;
        private bool _started;
        
        private void Start()
        {
            _started = true;
            InitializeChunks();
        }

        private void OnEnable()
        {
            if (_started) InitializeChunks();
        }

        private void InitializeChunks()
        {
            if (player == null)
            {
                Debug.LogError("WorldRenderer requires a player to stream chunks.", this);
                enabled = false;
                return;
            }

            // Keep the grid dimensions consistent if Inspector values change in play mode.
            _renderDistance = Mathf.Max(0, renderDistance);
            _chunkSize = Mathf.Max(1, chunkSize);
            var renderSize = 2 * _renderDistance + 1;
            _chunks = new Chunk[renderSize, renderSize, renderSize];
            _lastPlayerChunk = GetPlayerChunk();
            UpdateChunks(_lastPlayerChunk);
        }

        private void Update()
        {
            if (player == null || _chunks == null) return;

            var playerChunk = GetPlayerChunk();
            if (playerChunk != _lastPlayerChunk)
            {
                _lastPlayerChunk = playerChunk;
                UpdateChunks(playerChunk);
            }
        }

        private Vector3Int GetPlayerChunk()
        {
            return Vector3Int.FloorToInt(player.transform.position / _chunkSize);
        }

        private void UpdateChunks(Vector3Int playerChunk)
        {
            var renderSize = _chunks.GetLength(0);
            for (var i = 0; i < renderSize; i++)
                for (var j = 0; j < renderSize; j++)
                    for (var k = 0; k < renderSize; k++)
                    {
                        var coords = new Vector3Int(
                            playerChunk.x + i - _renderDistance,
                            playerChunk.y + j - _renderDistance,
                            playerChunk.z + k - _renderDistance);
                        
                        // Use the same coordinate-to-slot mapping at startup and on moves.
                        var x = Wrap(coords.x, renderSize);
                        var y = Wrap(coords.y, renderSize);
                        var z = Wrap(coords.z, renderSize);
                        var chunk = _chunks[x, y, z];
                        if (chunk == null)
                        {
                            chunk = new Chunk(_chunkSize, coords, fallback);
                            _chunks[x, y, z] = chunk;
                            chunk.Load(ParentChunk);
                        }
                        else if (chunk.Coords != coords)
                        {
                            // Loading and empty cells must also follow the player.
                            chunk.Reload(coords, ParentChunk);
                        }
                    }
        }

        private static int Wrap(int value, int size) => (value % size + size) % size;

        private void ParentChunk(GameObject instance)
        {
            instance.transform.SetParent(transform, true);
        }

        private void OnDisable()
        {
            if (_chunks == null) return;
            foreach (var chunk in _chunks) chunk?.Unload();
            _chunks = null;
        }
    }
}

#endif
