#!/bin/bash

echo "🚀 PizzaKV Heavy Benchmark Suite"
echo "=================================="
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
echo "📊 Running Heavy Benchmark Tests..."
echo ""

# Test 1: Heavy Write Load - 1M records
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Heavy Write Load (1M records)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET -n 1000000 -c 100 --threads 8 -r 1000000 -P 32 -d 256 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Heavy Read Load (1M reads)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t GET -n 1000000 -c 100 --threads 8 -r 1000000 -P 32 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Mixed Workload (500k each)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET,GET -n 500000 -c 100 --threads 8 -r 1000000 -P 32 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Large Values (10KB payloads)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET -n 100000 -c 50 --threads 4 -r 100000 -P 16 -d 10240 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: Extreme Concurrency (200 clients)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t SET,GET -n 500000 -c 200 --threads 8 -r 500000 -P 16 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Low Latency (no pipelining)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t GET -n 50000 -c 50 --threads 4 -r 1000000 -P 1 --csv

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: DELETE Performance"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
redis-benchmark -h localhost -p 8085 -t DEL -n 100000 -c 50 --threads 4 -r 1000000 -P 16 --csv

echo ""
echo "✅ Benchmark Complete!"
echo ""
echo "Checking persistence..."
ls -lh .db
echo ""
echo "Shutting down server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
