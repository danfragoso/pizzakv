# 🍕 PizzaKV

An in-memory key-value store written in Zig with Redis protocol compatibility and persistent storage.

## Overview

PizzaKV is a concurrent key-value database that implements a subset of the Redis RESP (REdis Serialization Protocol), allowing it to work with Redis clients for supported commands. It also supports a simpler custom protocol (Pizzaria Protocol) using `\r` delimiters. Built from scratch in Zig.

## Features

- **Dual Protocol Support**:
  - RESP (Redis Serialization Protocol) - subset implementation compatible with Redis clients
  - Pizzaria Protocol - simple `\r`-delimited custom protocol
- **Persistent Storage**: Append-only file (AOF) persistence with buffered writes
- **Prefix Search**: Built-in radix tree index for efficient prefix-based queries
- **Thread-Safe**: Concurrent operations using sharded hash tables and RwLocks
- **Zero Dependencies**: Pure Zig implementation with no external dependencies

## Supported Commands

### RESP Protocol (Redis-compatible)
- `SET key value` - Store a key-value pair
- `GET key` - Retrieve a value by key
- `DEL key` - Delete a key

### Pizzaria Protocol (`\r`-delimited)
- `write key|value` - Write a key-value pair (key and value separated by `|`)
- `read key` - Read a value by key
- `delete key` - Delete a key
- `keys` - Get all keys (using radix tree)
- `reads prefix` - Get all values for keys matching a prefix
- `status` - Server status check

## Architecture

### Core Components

- **Sharded Hash Table**: 64 shards with 1,048,576 total buckets for parallel access
- **Radix Tree Index**: Fast prefix search and key enumeration
- **Persistence Layer**: 8MB write buffer with automatic flushing
- **TCP Server**: Async I/O with connection pooling

### Concurrency Model

- **Per-shard RwLocks**: Allow concurrent reads within each shard
- **Global tree mutex**: Protects radix tree modifications
- **Atomic connection tracking**: For graceful shutdown

## Building

```bash
# Build optimized binary
make build

# Clean build artifacts
make clean
```

## Running

```bash
# Start server in Redis mode (RESP protocol, port 8085)
./pizzakv -redis

# Start server in Pizzaria mode (\r-delimited protocol, port 8085)
./pizzakv

# The server will create a .db file for persistence
```

## Technical Details

### Memory Management

- Arena allocators for hash table entries (per-shard)
- Arena allocator for radix tree nodes
- C allocator for temporary operations

### Hash Function

- FNV-1a hash with bit mixing for uniform distribution
- Minimizes collisions across 1M buckets

### Persistence Format

Simple append-only format:
```
OPCODE|key|value\r
```

- `W|key|value\r` - Write operation
- `D|key|\r` - Delete operation

### Thread Safety

- Shard-level RwLocks for concurrent hash table access
- Global mutex for radix tree operations
- Atomic counters for connection tracking

## Project Structure

```
pizzakv/
├── main.zig           # Server, connection handling
├── storage.zig        # Sharded hash table
├── index.zig          # Radix tree for prefix search
├── persistence.zig    # AOF persistence layer
├── hashing.zig        # Hash function
├── redis.zig          # RESP protocol parser
├── command.zig        # Command execution
├── socket.zig         # TCP socket operations
└── benchmark_*.sh     # Benchmark scripts
```

## Notes

- This implements a subset of RESP, not the full Redis protocol
- RESP commands are limited to SET, GET, and DEL
- The Pizzaria protocol provides additional commands (prefix search)
- Built with Zig 0.15.1 using `-O ReleaseFast` optimization
