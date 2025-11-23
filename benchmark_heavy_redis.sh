#!/bin/bash

echo "🔴 Redis Heavy Benchmark Suite"
echo "=================================="
echo ""

# Check if Redis is installed
if ! command -v redis-server &> /dev/null; then
    echo "❌ Redis is not installed"
    echo "Install with: brew install redis"
    exit 1
fi

# Check if Redis is running on default port
if nc -z localhost 6379 2>/dev/null; then
    echo "⚠️  Redis already running on port 6379"
    echo "Stopping existing Redis server..."
    redis-cli shutdown 2>/dev/null
    sleep 1
fi

# Clean up old AOF file
rm -f appendonly.aof

# Start fresh Redis instance with AOF persistence
echo "🗑️  Starting fresh Redis server with AOF persistence..."
redis-server --port 6379 --save "" --appendonly yes --appendfsync everysec &
REDIS_PID=$!
sleep 2

echo ""
echo "📊 Running Heavy Benchmark Tests on Redis..."
echo ""

# Test 1: Heavy Write Load - 1M records
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Heavy Write Load (1M records)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET -n 1000000 -c 100 --threads 8 -r 1000000 -P 32 -d 256 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Heavy Read Load (1M reads)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t GET -n 1000000 -c 100 --threads 8 -r 1000000 -P 32 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Mixed Workload (500k each)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET,GET -n 500000 -c 100 --threads 8 -r 1000000 -P 32 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Large Values (10KB payloads)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET -n 100000 -c 50 --threads 4 -r 100000 -P 16 -d 10240 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: Extreme Concurrency (200 clients)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t SET,GET -n 500000 -c 200 --threads 8 -r 500000 -P 16 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Low Latency (no pipelining)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t GET -n 50000 -c 50 --threads 4 -r 1000000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: DELETE Performance"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 6379 -t DEL -n 100000 -c 50 --threads 4 -r 1000000 -P 16 --csv

echo ""
echo "✅ Redis Benchmark Complete!"
echo ""
echo "Checking memory usage..."
redis-cli INFO memory | grep used_memory_human
echo ""
echo "Checking AOF persistence file..."
ls -lh appendonly.aof
echo ""
echo "Shutting down Redis..."
redis-cli shutdown
wait $REDIS_PID 2>/dev/null
