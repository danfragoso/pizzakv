#!/bin/bash

echo "🚀 PizzaKV No-Pipeline Benchmark Suite"
echo "========================================"
echo ""

# Remove old db to start fresh
echo "🗑️  Cleaning old data..."
pkill pizzakv 2>/dev/null
sleep 1
rm -f .db
echo "Starting fresh server..."
./pizzakv -redis &
SERVER_PID=$!
sleep 2

echo ""
echo "📊 Running No-Pipeline Benchmark Tests..."
echo ""

# Test 1: Small writes without pipelining
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Small Writes (100k, 256 bytes, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET -n 100000 -c 50 --threads 4 -r 100000 -P 1 -d 256 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Small Reads (100k, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t GET -n 100000 -c 50 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Medium Writes (50k, 1KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET -n 50000 -c 50 --threads 4 -r 50000 -P 1 -d 1024 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Medium Reads (50k, 1KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t GET -n 50000 -c 50 --threads 4 -r 50000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: Large Writes (10k, 10KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET -n 10000 -c 25 --threads 2 -r 10000 -P 1 -d 10240 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Large Reads (10k, 10KB, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t GET -n 10000 -c 25 --threads 2 -r 10000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: Mixed Workload (50k each, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET,GET -n 50000 -c 50 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 8: High Concurrency (100k, 100 clients, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t GET -n 100000 -c 100 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 9: DELETE Performance (50k, P=1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t DEL -n 50000 -c 50 --threads 4 -r 100000 -P 1 --csv

echo ""
echo "✅ Benchmark Complete!"
echo ""
echo "Checking persistence..."
ls -lh .db
echo ""
echo "Shutting down server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
