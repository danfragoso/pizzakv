#!/bin/bash

echo "🔴 Redis No-Pipeline Benchmark Suite"
echo "======================================"
echo ""

# Check if Redis is running on default port
if nc -z localhost 6379 2>/dev/null; then
    echo "⚠️  Redis already running on port 6379"
    echo "Stopping existing Redis server..."
    redis-cli shutdown 2>/dev/null
    sleep 1
fi

# Clean up old AOF files
rm -f appendonly.aof*

# Start fresh Redis instance with AOF persistence
echo "🗑️  Starting fresh Redis server with AOF persistence..."
redis-server --port 6379 --save "" --appendonly yes --appendfsync everysec &
REDIS_PID=$!
sleep 2

echo ""
echo "📊 Running No-Pipeline Benchmark Tests on Redis..."
echo ""

# Test 1: Small writes without pipelining
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Small Writes (100k, 256 bytes, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET -n 100000 -c 50 --threads 4 -r 100000 -P 1 -d 256 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Small Reads (100k, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t GET -n 100000 -c 50 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Medium Writes (50k, 1KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET -n 50000 -c 50 --threads 4 -r 50000 -P 1 -d 1024 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Medium Reads (50k, 1KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t GET -n 50000 -c 50 --threads 4 -r 50000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: Large Writes (10k, 10KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET -n 10000 -c 25 --threads 2 -r 10000 -P 1 -d 10240 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Large Reads (10k, 10KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t GET -n 10000 -c 25 --threads 2 -r 10000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: Mixed Workload (50k each, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET,GET -n 50000 -c 50 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 8: High Concurrency (100k, 100 clients, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t GET -n 100000 -c 100 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 9: DELETE Performance (50k, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t DEL -n 50000 -c 50 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "✅ Redis Benchmark Complete!"
echo ""
echo "Checking memory usage..."
redis-cli INFO memory | grep used_memory_human
echo ""
echo "Checking AOF persistence files..."
ls -lh appendonly.aof* 2>/dev/null || echo "AOF files managed by Redis"
echo ""
echo "Shutting down Redis..."
redis-cli shutdown
wait $REDIS_PID 2>/dev/null
