// Simple test to verify server is working
const http = require('http');

const options = {
  hostname: 'localhost',
  port: 8080,
  path: '/health',
  method: 'GET'
};

const req = http.request(options, (res) => {
  console.log(`✅ Server responded with status: ${res.statusCode}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('✅ Response:', data);
    console.log('🎉 Server is working correctly!');
  });
});

req.on('error', (error) => {
  console.error('❌ Server test failed:', error.message);
});

req.end();