const net = require('net');

class KVClient {
  constructor(host = 'localhost', port = 8080) {
    this.host = host;
    this.port = port;
    this.client = null;
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.client = net.createConnection({ host: this.host, port: this.port }, () => {
        console.log('Connected to KV database');
        resolve();
      });

      this.client.on('error', (err) => {
        reject(err);
      });
    });
  }

  sendCommand(command) {
    return new Promise((resolve, reject) => {
      let response = '';

      const dataHandler = (data) => {
        response += data.toString();
        // Assuming responses end with \r
        if (response.includes('\r')) {
          this.client.removeListener('data', dataHandler);
          resolve(response.replace(/\r/g, '').trim());
        }
      };

      this.client.on('data', dataHandler);

      this.client.write(command + '\r', (err) => {
        if (err) {
          this.client.removeListener('data', dataHandler);
          reject(err);
        }
      });

      // Timeout after 5 seconds
      setTimeout(() => {
        this.client.removeListener('data', dataHandler);
        reject(new Error('Command timeout'));
      }, 5000);
    });
  }

  async write(key, value) {
    return await this.sendCommand(`write ${key}|${value}`);
  }

  async read(key) {
    return await this.sendCommand(`read ${key}`);
  }

  close() {
    if (this.client) {
      this.client.end();
    }
  }
}

async function testBatch(client, batchSize, batchNum, allResults) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`BATCH ${batchNum}: Writing and verifying ${batchSize.toLocaleString()} entries`);
  console.log('='.repeat(60));

  const batchData = new Map();
  const batchResults = {
    batchSize,
    batchNum,
    successfulWrites: 0,
    failedWrites: 0,
    successfulReads: 0,
    failedReads: 0,
    mismatches: 0,
    errors: []
  };

  // Write phase
  console.log(`\nWriting ${batchSize.toLocaleString()} entries...`);
  const startWrite = Date.now();
  
  for (let i = 0; i < batchSize; i++) {
    const key = `key_batch${batchNum}_${i}`;
    const value = `value_${batchNum}_${i}_${Math.random().toString(36).substring(7)}`;
    batchData.set(key, value);
    
    try {
      await client.write(key, value);
      batchResults.successfulWrites++;
    } catch (err) {
      batchResults.failedWrites++;
      batchResults.errors.push({ operation: 'write', key, error: err.message });
    }

    if ((i + 1) % Math.max(1, Math.floor(batchSize / 10)) === 0) {
      const progress = ((i + 1) / batchSize * 100).toFixed(1);
      process.stdout.write(`\r  Progress: ${(i + 1).toLocaleString()}/${batchSize.toLocaleString()} (${progress}%)`);
    }
  }
  
  const writeDuration = Date.now() - startWrite;
  console.log(`\n  Completed in ${writeDuration}ms (${(writeDuration / 1000).toFixed(2)}s) - ${(batchSize / (writeDuration / 1000)).toFixed(2)} writes/sec`);

  // Read and verify phase
  console.log(`\nVerifying ${batchSize.toLocaleString()} entries...`);
  const startRead = Date.now();
  
  let readCount = 0;
  for (const [key, expectedValue] of batchData) {
    try {
      const response = await client.read(key);
      readCount++;
      
      // Parse response (adjust based on your server's response format)
      const actualValue = response.includes('|') ? response.split('|')[1] : response;
      
      if (actualValue === expectedValue) {
        batchResults.successfulReads++;
      } else {
        batchResults.mismatches++;
        batchResults.errors.push({
          operation: 'read',
          key,
          expected: expectedValue,
          actual: actualValue
        });
      }
      
      if (readCount % Math.max(1, Math.floor(batchSize / 10)) === 0) {
        const progress = (readCount / batchSize * 100).toFixed(1);
        process.stdout.write(`\r  Progress: ${readCount.toLocaleString()}/${batchSize.toLocaleString()} (${progress}%)`);
      }
    } catch (err) {
      batchResults.failedReads++;
      batchResults.errors.push({ operation: 'read', key, error: err.message });
    }
  }
  
  const readDuration = Date.now() - startRead;
  console.log(`\n  Completed in ${readDuration}ms (${(readDuration / 1000).toFixed(2)}s) - ${(batchSize / (readDuration / 1000)).toFixed(2)} reads/sec`);

  // Batch summary
  const batchSuccess = batchResults.failedWrites === 0 && 
                       batchResults.failedReads === 0 && 
                       batchResults.mismatches === 0;
  
  console.log(`\nBatch ${batchNum} Results:`);
  console.log(`  Writes: ${batchResults.successfulWrites}/${batchSize} successful`);
  console.log(`  Reads: ${batchResults.successfulReads}/${batchSize} successful`);
  console.log(`  Status: ${batchSuccess ? '✓ PASSED' : '✗ FAILED'}`);

  if (batchResults.errors.length > 0) {
    console.log(`  Errors: ${batchResults.errors.length} (showing first 5):`);
    batchResults.errors.slice(0, 5).forEach((err, idx) => {
      console.log(`    ${idx + 1}. ${err.operation.toUpperCase()} ${err.key}: ${err.error || 'Value mismatch'}`);
    });
  }

  allResults.push(batchResults);
  return batchData;
}

async function testKVDatabase() {
  const client = new KVClient('localhost', 8080);
  const allResults = [];
  const allData = new Map();

  // Batch sizes: 1K, 10K, 100K, 1M
  const batches = [
    { size: 1000, label: '1K' },
    { size: 10000, label: '10K' },
    { size: 100000, label: '100K' },
    { size: 1000000, label: '1M' }
  ];

  try {
    await client.connect();

    const overallStart = Date.now();

    for (let i = 0; i < batches.length; i++) {
      const batchData = await testBatch(client, batches[i].size, i + 1, allResults);
      // Store all data for potential final verification
      for (const [key, value] of batchData) {
        allData.set(key, value);
      }
    }

    const overallDuration = Date.now() - overallStart;

    // Final comprehensive report
    console.log('\n\n' + '='.repeat(60));
    console.log('FINAL COMPREHENSIVE REPORT');
    console.log('='.repeat(60));

    let totalWrites = 0, successfulWrites = 0, failedWrites = 0;
    let totalReads = 0, successfulReads = 0, failedReads = 0, totalMismatches = 0;
    let totalErrors = 0;

    console.log('\nPer-Batch Summary:');
    allResults.forEach((batch) => {
      totalWrites += batch.batchSize;
      successfulWrites += batch.successfulWrites;
      failedWrites += batch.failedWrites;
      successfulReads += batch.successfulReads;
      failedReads += batch.failedReads;
      totalMismatches += batch.mismatches;
      totalErrors += batch.errors.length;

      const batchSuccess = batch.failedWrites === 0 && batch.failedReads === 0 && batch.mismatches === 0;
      console.log(`  Batch ${batch.batchNum} (${batch.batchSize.toLocaleString()}): ${batchSuccess ? '✓ PASSED' : '✗ FAILED'}`);
    });

    console.log(`\nOverall Statistics:`);
    console.log(`  Total entries: ${allData.size.toLocaleString()}`);
    console.log(`  Total time: ${overallDuration}ms (${(overallDuration / 1000).toFixed(2)}s)`);
    console.log(`  Average throughput: ${(totalWrites / (overallDuration / 1000)).toFixed(2)} operations/sec`);

    console.log(`\nWrite Operations:`);
    console.log(`  Total: ${totalWrites.toLocaleString()}`);
    console.log(`  Successful: ${successfulWrites.toLocaleString()}`);
    console.log(`  Failed: ${failedWrites.toLocaleString()}`);
    console.log(`  Success rate: ${((successfulWrites / totalWrites) * 100).toFixed(2)}%`);

    console.log(`\nRead Operations:`);
    console.log(`  Total: ${totalReads.toLocaleString()}`);
    console.log(`  Successful: ${successfulReads.toLocaleString()}`);
    console.log(`  Failed: ${failedReads.toLocaleString()}`);
    console.log(`  Mismatches: ${totalMismatches.toLocaleString()}`);
    console.log(`  Success rate: ${((successfulReads / totalReads) * 100).toFixed(2)}%`);

    const overallSuccess = failedWrites === 0 && failedReads === 0 && totalMismatches === 0;
    console.log(`\n${'='.repeat(60)}`);
    console.log(`FINAL RESULT: ${overallSuccess ? '✓ ALL TESTS PASSED!' : '✗ SOME TESTS FAILED'}`);
    console.log('='.repeat(60));

    if (totalErrors > 0) {
      console.log(`\nTotal errors across all batches: ${totalErrors}`);
    }

  } catch (err) {
    console.error('\nConnection error:', err.message);
  } finally {
    client.close();
  }
}

// Run the test
console.log('Starting KV Database Progressive Load Test');
console.log('Testing batches: 1K → 10K → 100K → 1M entries\n');

testKVDatabase().catch(console.error);
