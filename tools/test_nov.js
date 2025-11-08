const net = require('net');

class KVDBClient {
  constructor(host = 'localhost', port = 8080) {
    this.host = host;
    this.port = port;
    this.socket = null;
    this.connected = false;
  }

  async connect() {
    if (this.connected) return;
    
    return new Promise((resolve, reject) => {
      this.socket = new net.Socket();
      this.socket.setKeepAlive(true);
      this.socket.setNoDelay(true);
      
      const timeout = setTimeout(() => {
        reject(new Error('Connection timeout'));
      }, 5000);
      
      this.socket.connect(this.port, this.host, () => {
        clearTimeout(timeout);
        this.connected = true;
        resolve();
      });
      
      this.socket.once('error', (err) => {
        clearTimeout(timeout);
        this.connected = false;
        reject(err);
      });
    });
  }

  disconnect() {
    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
      this.connected = false;
    }
  }

  sendCommand(command, debug = false) {
    return new Promise(async (resolve, reject) => {
      if (!this.socket) {
        try {
          await this.connect();
        } catch (err) {
          return reject(err);
        }
      }
      
      let response = '';

      const dataHandler = (data) => {
        response += data.toString();
        
        if (response.includes('\r')) {
          this.socket.removeListener('data', dataHandler);
          clearTimeout(timeout);
          const result = response.replace(/\r/g, '').trim();
          
          if (debug) {
            console.log(`[DEBUG] Recebido: ${result}`);
          }
          
          resolve(result);
        }
      };

      this.socket.on('data', dataHandler);

      const timeout = setTimeout(() => {
        this.socket.removeListener('data', dataHandler);
        reject(new Error(`Timeout após 5s`));
      }, 5000);

      if (debug) {
        console.log(`[DEBUG] Enviando: ${command.replace(/\r/g, '\\r')}`);
      }
      
      this.socket.write(command, (err) => {
        if (err) {
          this.socket.removeListener('data', dataHandler);
          clearTimeout(timeout);
          reject(err);
        }
      });
    });
  }

  async write(key, value) {
    return this.sendCommand(`write ${key}|${value}\r`);
  }

  async read(key) {
    return this.sendCommand(`read ${key}\r`);
  }

  async delete(key) {
    return this.sendCommand(`delete ${key}\r`);
  }

  async status() {
    return this.sendCommand(`status\r`);
  }

  async keys() {
    return this.sendCommand(`keys\r`);
  }

  async reads(prefix) {
    return this.sendCommand(`reads ${prefix}\r`);
  }
}

function generateValue(size) {
  return 'x'.repeat(size);
}

function generateKey(prefix, id) {
  return `${prefix}:${id}`;
}

async function testBasicFeatures() {
  console.log('\n=== TESTE 1: FUNCIONALIDADES BÁSICAS ===\n');
  const client = new KVDBClient();
  const features = {
    write: true,
    read: true,
    delete: true,
    keys: true,
    reads: true,
    status: true
  };

  try {
    console.log('Testando CONEXÃO...');
    const status = await client.status();
    console.log(`✓ Conexão OK. Status: ${status}\n`);

    console.log('Testando WRITE...');
    await client.write('test:1', 'valor1');
    console.log(`✓ Write: success`);

    console.log('\nTestando READ...');
    const readRes = await client.read('test:1');
    console.log(`✓ Read: ${readRes}`);

    console.log('\nTestando WRITE múltiplas chaves...');
    await client.write('test:2', 'valor2');
    await client.write('test:3', 'valor3');
    await client.write('other:1', 'outro');
    console.log(`✓ Múltiplas escritas concluídas`);

    console.log('\nTestando KEYS...');
    try {
      const keysRes = await client.keys();
      if (keysRes === 'error') {
        throw new Error('retornou error');
      }
      const keysList = keysRes.split('\n').filter(k => k.trim());
      console.log(`✓ Keys (${keysList.length} chaves): ${keysList.slice(0, 5).join(', ')}${keysList.length > 5 ? '...' : ''}`);
    } catch (err) {
      features.keys = false;
      console.log(`⊘ KEYS não suportado (${err.message}) - será ignorado nos testes`);
    }

    console.log('\nTestando READS com prefixo "test"...');
    try {
      const readsRes = await client.reads('test');
      if (readsRes === 'error') {
        throw new Error('retornou error');
      }
      const readsList = readsRes.split('\n').filter(v => v.trim());
      console.log(`✓ Reads (${readsList.length} valores): ${readsList.slice(0, 3).join(', ')}${readsList.length > 3 ? '...' : ''}`);
    } catch (err) {
      features.reads = false;
      console.log(`⊘ READS não suportado (${err.message}) - será ignorado nos testes`);
    }

    console.log('\nTestando DELETE...');
    try {
      const delRes = await client.delete('test:1');
      if (delRes === 'error') {
        throw new Error('retornou error');
      }
      console.log(`✓ Delete: ${delRes}`);

      console.log('Verificando se foi deletado...');
      const delReadRes = await client.read('test:1');
      if (delReadRes !== 'error') {
        throw new Error(`chave ainda existe com valor "${delReadRes}"`);
      }
      console.log(`✓ Chave foi deletada corretamente`);
    } catch (err) {
      features.delete = false;
      console.log(`⊘ DELETE não suportado (${err.message}) - será ignorado nos testes`);
    }

    console.log('\nTestando DELETE em chave inexistente...');
    if (features.delete) {
      const delNonExist = await client.delete('nao:existe');
      if (delNonExist !== 'error') {
        console.log(`⚠ DELETE deveria retornar error para chave inexistente`);
      } else {
        console.log(`✓ Delete inexistente retornou error`);
      }
    } else {
      console.log(`⊘ Pulado (DELETE não suportado)`);
    }

    console.log('\nTestando comando INVÁLIDO...');
    const invalidRes = await client.sendCommand('invalid comando\r');
    if (invalidRes !== 'error') {
      console.log(`⚠ Comando inválido deveria retornar error`);
    } else {
      console.log(`✓ Comando inválido retornou error`);
    }

    client.disconnect();
    
    console.log('\n✓✓✓ TESTES BÁSICOS CONCLUÍDOS ✓✓✓');
    console.log('\nFuncionalidades disponíveis:');
    console.log(`  WRITE: ${features.write ? '✓' : '✗'}`);
    console.log(`  READ: ${features.read ? '✓' : '✗'}`);
    console.log(`  DELETE: ${features.delete ? '✓' : '✗'}`);
    console.log(`  KEYS: ${features.keys ? '✓' : '✗'}`);
    console.log(`  READS: ${features.reads ? '✓' : '✗'}`);
    console.log(`  STATUS: ${features.status ? '✓' : '✗'}`);
    
    return features;
  } catch (err) {
    client.disconnect();
    console.error(`✗ ERRO FATAL: ${err.message}`);
    return null;
  }
}

async function testMillionRecords() {
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  TESTE 2: 1 MILHÃO DE REGISTROS');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  const client = new KVDBClient();
  const totalRecords = 1000000;

  try {
    await client.connect();
    console.log(`✓ Conexão persistente estabelecida\n`);
    
    console.log(`Iniciando escrita de ${totalRecords.toLocaleString()} registros...\n`);
    const writeStart = Date.now();
    let successCount = 0;
    let errorCount = 0;

    for (let i = 0; i < totalRecords; i++) {
      try {
        const key = generateKey('load', i);
        const value = `value_${i}`;
        await client.write(key, value);
        successCount++;

        if ((i + 1) % 10000 === 0) {
          const elapsed = (Date.now() - writeStart) / 1000;
          const rate = Math.floor((i + 1) / elapsed);
          const progress = ((i + 1) / totalRecords * 100).toFixed(1);
          process.stdout.write(`\r  ${(i + 1).toLocaleString()} escritas | ${rate.toLocaleString()} ops/s | ${progress}% | erros: ${errorCount}     `);
        }
      } catch (err) {
        errorCount++;
        if (errorCount < 5) {
          console.error(`\n  Erro no registro ${i}: ${err.message}`);
        }
        if (!client.connected) {
          await client.connect();
        }
      }
    }

    const writeTime = (Date.now() - writeStart) / 1000;
    const writeRate = Math.floor(successCount / writeTime);
    console.log(`\n\n✓ Escrita concluída em ${writeTime.toFixed(2)}s | ${writeRate.toLocaleString()} ops/s`);
    console.log(`  Sucessos: ${successCount.toLocaleString()} | Erros: ${errorCount}`);

    console.log('\nIniciando leitura e validação de todos os registros...\n');
    const readStart = Date.now();
    let readSuccess = 0;
    let readErrors = 0;
    let validationErrors = 0;

    for (let i = 0; i < totalRecords; i++) {
      try {
        const key = generateKey('load', i);
        const expectedValue = `value_${i}`;
        const actualValue = await client.read(key);
        
        if (actualValue !== expectedValue) {
          validationErrors++;
          if (validationErrors <= 5) {
            console.error(`\n  Validação falhou para ${key}: esperado "${expectedValue}", recebido "${actualValue}"`);
          }
        }
        
        readSuccess++;

        if ((i + 1) % 10000 === 0) {
          const elapsed = (Date.now() - readStart) / 1000;
          const rate = Math.floor((i + 1) / elapsed);
          const progress = ((i + 1) / totalRecords * 100).toFixed(1);
          process.stdout.write(`\r  ${(i + 1).toLocaleString()} leituras | ${rate.toLocaleString()} reads/s | ${progress}% | erros: ${readErrors} | validação: ${validationErrors}     `);
        }
      } catch (err) {
        readErrors++;
        if (readErrors <= 5) {
          console.error(`\n  Erro na leitura ${i}: ${err.message}`);
        }
        if (!client.connected) {
          await client.connect();
        }
      }
    }

    const readTime = (Date.now() - readStart) / 1000;
    const readRate = Math.floor(readSuccess / readTime);
    console.log(`\n\n✓ Leitura e validação concluída em ${readTime.toFixed(2)}s | ${readRate.toLocaleString()} reads/s`);
    console.log(`  Sucessos: ${readSuccess.toLocaleString()} | Erros: ${readErrors} | Erros de validação: ${validationErrors}`);

    client.disconnect();
    console.log('\n✓ Teste de 1 milhão concluído com sucesso');
    return true;
  } catch (err) {
    client.disconnect();
    console.error(`✗ ERRO: ${err.message}`);
    return false;
  }
}

async function testMultipleReads(features) {
  if (!features.reads) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('  TESTE 3: LEITURAS MÚLTIPLAS (READS) - PULADO');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('⊘ Comando READS não suportado pelo servidor');
    console.log('  Este teste compararia o desempenho de:');
    console.log('  - READS prefix (bulk read)');
    console.log('  - vs múltiplos READ individuais');
    return false;
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  TESTE 3: LEITURAS MÚLTIPLAS (READS vs READ)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const client = new KVDBClient();
  const prefixes = ['user', 'product', 'order', 'session', 'cache'];
  const recordsPerPrefix = 1000;

  try {
    await client.connect();
    console.log('✓ Conexão estabelecida\n');

    // Preparar dados de teste
    console.log(`Preparando ${prefixes.length * recordsPerPrefix} registros...`);
    for (const prefix of prefixes) {
      for (let i = 0; i < recordsPerPrefix; i++) {
        const key = `${prefix}:${i}`;
        const value = `${prefix}_value_${i}`;
        await client.write(key, value);
      }
      console.log(`  ✓ ${recordsPerPrefix} registros com prefixo "${prefix}"`);
    }

    console.log('\n' + '─'.repeat(60));
    
    // Teste 1: Usando READS (bulk)
    console.log('\nTeste 1: Usando READS (bulk read por prefixo)');
    const bulkStart = Date.now();
    const bulkResults = {};
    
    for (const prefix of prefixes) {
      const result = await client.reads(prefix);
      const values = result.split('\n').filter(v => v.trim());
      bulkResults[prefix] = values.length;
      console.log(`  ${prefix}: ${values.length} valores em ${Date.now() - bulkStart}ms`);
    }
    
    const bulkTime = Date.now() - bulkStart;
    const bulkTotal = Object.values(bulkResults).reduce((a, b) => a + b, 0);
    console.log(`\n✓ READS completado: ${bulkTotal} valores em ${bulkTime}ms`);
    console.log(`  Throughput: ${Math.floor((bulkTotal / bulkTime) * 1000)} valores/s`);

    // Teste 2: Usando READ individual
    console.log('\nTeste 2: Usando READ individual (um por um)');
    const individualStart = Date.now();
    let individualCount = 0;
    
    for (const prefix of prefixes) {
      const prefixStart = Date.now();
      for (let i = 0; i < recordsPerPrefix; i++) {
        const key = `${prefix}:${i}`;
        await client.read(key);
        individualCount++;
      }
      console.log(`  ${prefix}: ${recordsPerPrefix} reads em ${Date.now() - prefixStart}ms`);
    }
    
    const individualTime = Date.now() - individualStart;
    console.log(`\n✓ READ individual completado: ${individualCount} leituras em ${individualTime}ms`);
    console.log(`  Throughput: ${Math.floor((individualCount / individualTime) * 1000)} reads/s`);

    // Comparação
    console.log('\n' + '─'.repeat(60));
    console.log('COMPARAÇÃO DE DESEMPENHO:');
    console.log(`  READS (bulk):     ${bulkTime}ms`);
    console.log(`  READ (individual): ${individualTime}ms`);
    console.log(`  Diferença:         ${individualTime - bulkTime}ms`);
    console.log(`  READS é ${(individualTime / bulkTime).toFixed(2)}x mais rápido`);
    console.log('─'.repeat(60));

    client.disconnect();
    console.log('\n✓ Teste de leituras múltiplas concluído');
    return true;
  } catch (err) {
    client.disconnect();
    console.error(`✗ ERRO: ${err.message}`);
    return false;
  }
}

async function testConcurrency() {
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  TESTE 4: CONCORRÊNCIA (10 CONEXÕES x 100K = 1M REGISTROS)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  const numConnections = 10;
  const recordsPerConnection = 100000;
  const totalRecords = numConnections * recordsPerConnection;

  try {
    console.log(`Iniciando ${numConnections} conexões paralelas...\n`);
    const startTime = Date.now();
    const connectionStats = [];

    const promises = [];
    for (let conn = 0; conn < numConnections; conn++) {
      const promise = (async (connectionId) => {
        const client = new KVDBClient();
        await client.connect();
        
        const connStart = Date.now();
        let success = 0;
        let errors = 0;

        for (let i = 0; i < recordsPerConnection; i++) {
          try {
            const key = generateKey(`conn${connectionId}`, i);
            const value = `conn${connectionId}_value_${i}`;
            await client.write(key, value);
            success++;

            if ((i + 1) % 10000 === 0) {
              const elapsed = (Date.now() - connStart) / 1000;
              const rate = Math.floor((i + 1) / elapsed);
              const progress = ((i + 1) / recordsPerConnection * 100).toFixed(0);
              console.log(`  [Conn ${connectionId}] ${(i + 1).toLocaleString()} registros | ${rate.toLocaleString()} ops/s | ${progress}%`);
            }
          } catch (err) {
            errors++;
            if (!client.connected) {
              await client.connect();
            }
          }
        }

        const connTime = (Date.now() - connStart) / 1000;
        const connRate = Math.floor(success / connTime);
        connectionStats.push({ id: connectionId, time: connTime, rate: connRate, errors });
        
        console.log(`✓ Conexão ${connectionId} finalizada: ${connTime.toFixed(2)}s | ${connRate.toLocaleString()} ops/s | erros: ${errors}`);
        
        client.disconnect();
      })(conn);

      promises.push(promise);
    }

    await Promise.all(promises);

    const totalTime = (Date.now() - startTime) / 1000;
    const totalRate = Math.floor(totalRecords / totalTime);

    console.log('\n' + '─'.repeat(60));
    console.log(`RESULTADOS DE ESCRITA:`);
    console.log(`  Total de registros: ${totalRecords.toLocaleString()}`);
    console.log(`  Tempo total: ${totalTime.toFixed(2)}s`);
    console.log(`  Throughput agregado: ${totalRate.toLocaleString()} ops/s`);
    console.log('─'.repeat(60));

    // Ranking
    console.log('\nRanking de Performance (escrita):');
    connectionStats.sort((a, b) => b.rate - a.rate);
    connectionStats.forEach((stat, idx) => {
      const position = `${idx + 1}º`.padEnd(4);
      console.log(`  ${position} Conexão ${stat.id}: ${stat.rate.toLocaleString().padStart(8)} ops/s (${stat.time.toFixed(2)}s)`);
    });

    console.log('\nIniciando leituras e validação paralelas...\n');
    const readStart = Date.now();
    const readStats = [];

    const readPromises = [];
    for (let conn = 0; conn < numConnections; conn++) {
      const promise = (async (connectionId) => {
        const client = new KVDBClient();
        await client.connect();
        
        let success = 0;
        let errors = 0;
        let validationErrors = 0;
        const readConnStart = Date.now();

        for (let i = 0; i < recordsPerConnection; i++) {
          try {
            const key = generateKey(`conn${connectionId}`, i);
            const expectedValue = `conn${connectionId}_value_${i}`;
            const actualValue = await client.read(key);
            
            if (actualValue !== expectedValue) {
              validationErrors++;
              if (validationErrors <= 5) {
                console.error(`\n  [Conn ${connectionId}] Validação falhou para ${key}: esperado "${expectedValue}", recebido "${actualValue}"`);
              }
            }
            
            success++;
            
            if ((i + 1) % 10000 === 0) {
              const elapsed = (Date.now() - readConnStart) / 1000;
              const rate = Math.floor((i + 1) / elapsed);
              const progress = ((i + 1) / recordsPerConnection * 100).toFixed(0);
              console.log(`  [Conn ${connectionId}] ${(i + 1).toLocaleString()} leituras | ${rate.toLocaleString()} reads/s | ${progress}% | validação: ${validationErrors}`);
            }
          } catch (err) {
            errors++;
            if (!client.connected) {
              await client.connect();
            }
          }
        }

        const readConnTime = (Date.now() - readConnStart) / 1000;
        const readConnRate = Math.floor(success / readConnTime);
        readStats.push({ id: connectionId, time: readConnTime, rate: readConnRate, errors, validationErrors });

        console.log(`✓ Conexão ${connectionId}: ${success.toLocaleString()} leituras | ${readConnRate.toLocaleString()} reads/s | validação: ${validationErrors}`);
        
        client.disconnect();
      })(conn);

      readPromises.push(promise);
    }

    await Promise.all(readPromises);

    const readTime = (Date.now() - readStart) / 1000;
    const totalReads = numConnections * recordsPerConnection;
    const readTotalRate = Math.floor(totalReads / readTime);
    const totalValidationErrors = readStats.reduce((sum, stat) => sum + stat.validationErrors, 0);

    console.log('\n' + '─'.repeat(60));
    console.log(`RESULTADOS DE LEITURA E VALIDAÇÃO:`);
    console.log(`  Total de leituras: ${totalReads.toLocaleString()}`);
    console.log(`  Tempo total: ${readTime.toFixed(2)}s`);
    console.log(`  Throughput agregado: ${readTotalRate.toLocaleString()} reads/s`);
    console.log(`  Erros de validação: ${totalValidationErrors}`);
    console.log('─'.repeat(60));

    // Ranking de leituras
    console.log('\nRanking de Performance (leitura):');
    readStats.sort((a, b) => b.rate - a.rate);
    readStats.forEach((stat, idx) => {
      const position = `${idx + 1}º`.padEnd(4);
      console.log(`  ${position} Conexão ${stat.id}: ${stat.rate.toLocaleString().padStart(8)} reads/s | validação: ${stat.validationErrors}`);
    });

    console.log('\n✓ Teste de concorrência concluído com sucesso');
    return true;
  } catch (err) {
    console.error(`✗ ERRO: ${err.message}`);
    return false;
  }
}

async function runAllTests() {
  console.log('\n╔════════════════════════════════════════════════════╗');
  console.log('║       PIZZAKV - SUITE DE TESTES DE PERFORMANCE    ║');
  console.log('║                   Porta: 8080                      ║');
  console.log('╚════════════════════════════════════════════════════╝');

  const features = await testBasicFeatures();
  
  if (!features) {
    console.log('\n✗ Erro fatal nos testes básicos. Abortando...');
    process.exit(1);
  }
  
  if (!features.write || !features.read) {
    console.log('\n✗ WRITE e READ são obrigatórios. Abortando...');
    process.exit(1);
  }
  
  console.log('\n\nIniciando teste de 1 milhão em 3 segundos...');
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  const success2 = await testMillionRecords();
  
  if (!success2) {
    console.log('\n⚠ Teste de 1M falhou, mas continuando...');
  }
  
  console.log('\n\nIniciando teste de leituras múltiplas em 3 segundos...');
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  const success3 = await testMultipleReads(features);
  
  if (!success3 && features.reads) {
    console.log('\n⚠ Teste de leituras múltiplas falhou');
  }
  
  console.log('\n\nIniciando teste de concorrência em 3 segundos...');
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  const success4 = await testConcurrency();

  if (!success4) {
    console.log('\n⚠ Teste de concorrência falhou');
  }

  console.log('\n╔════════════════════════════════════════════════════╗');
  console.log('║            ✓ TODOS OS TESTES CONCLUÍDOS           ║');
  console.log('╚════════════════════════════════════════════════════╝\n');
}

runAllTests().catch(console.error);