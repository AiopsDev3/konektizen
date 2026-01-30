import axios from 'axios';

const BASE_URL = 'http://172.16.0.101:3000/api';

async function main() {
  console.log('--- Verifying C3 API Proxy ---');

  // 1. Test Registration Proxy
  try {
    console.log('Testing Registration...');
    const regRes = await axios.post(`${BASE_URL}/auth/register`, {
      email: `test_${Date.now()}@example.com`,
      password: 'password123',
      fullName: 'Test Proxy User',
      phoneNumber: `09${Math.floor(Math.random()*1000000000)}`
    });
    console.log('✅ Registration Success. Data:', JSON.stringify(regRes.data, null, 2));
  } catch (e: any) {
    if (e.response && e.response.status !== 500) {
       console.log(`⚠️ Registration returned ${e.response.status} (Likely C3 API response):`, e.response.data);
    } else {
       console.error('❌ Registration Failed:', e.message);
    }
  }

  // 2. Test Login Proxy (using dummy creds, expecting C3 error or success)
  let token = '';
  try {
    console.log('Testing Login...');
    const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
      email: 'admin@example.com', // Try a likely existing user or random
      password: 'password' 
    });
    console.log('✅ Login Success. Data:', JSON.stringify(loginRes.data, null, 2));
    token = loginRes.data.token;
  } catch (e: any) {
     if (e.response && e.response.status !== 500) {
       console.log(`⚠️ Login returned ${e.response.status} (Likely C3 API response):`, e.response.data);
    } else {
       console.error('❌ Login Failed:', e.message);
    }
  }

  // 3. Test SOS Proxy
  if (token) {
    try {
      console.log('Testing SOS...');
      const sosRes = await axios.post(`${BASE_URL}/sos`, {
        latitude: 14.5,
        longitude: 121.0
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      console.log('✅ SOS Success:', sosRes.data);
    } catch (e: any) {
      if (e.response && e.response.status !== 500) {
       console.log(`⚠️ SOS returned ${e.response.status} (Likely C3 API response):`, e.response.data);
      } else {
       console.error('❌ SOS Failed:', e.message);
      }
    }
  } else {
      console.log('Skipping SOS test (no token)');
  }
}

main();
