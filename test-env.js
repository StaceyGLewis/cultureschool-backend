// test-env.js
const path = require('path');
const result = require('dotenv').config({ path: path.resolve(__dirname, '.env') });
console.log('dotenv status:', result.error ? result.error : 'loaded ✅');
console.log('parsed keys:', Object.keys(result.parsed || {}));
console.log('OPENAI_API_KEY present?', !!process.env.OPENAI_API_KEY);
console.log('OPENAI_API_KEY prefix:', (process.env.OPENAI_API_KEY || 'missing').slice(0,8));
