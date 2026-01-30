import axios from 'axios';

const BASE_URL = 'http://172.16.0.101:3000/api';

async function main() {
  console.log('--- Debugging SOS Flow ---');
  
  // 1. Get a valid user (assuming previous scripts created one, or create new)
  const uniqueId = Date.now().toString();
  const email = `sos_debug_${uniqueId}@test.com`;
  const password = 'password123';
  const phone = `09${Math.floor(Math.random() * 1000000000)}`;
  
  console.log(`1. Registering: ${email} ...`);
  try {
    await axios.post(`${BASE_URL}/auth/register`, {
      email,
      password,
      fullName: `SOS Debugger ${uniqueId}`,
      phoneNumber: phone
    });
  } catch(e) {}

  // 2. Login
  console.log('2. Logging in...');
  let token = '';
  try {
    const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
      email,
      password
    });
    token = loginRes.data.token;
    console.log('✅ Login Success. Token:', token ? 'Yes' : 'No');
  } catch (e: any) {
    console.error('❌ Login Failed (cannot test SOS):', e.response?.data || e.message);
    return;
  }

  // 3. Send SOS
  console.log('3. Sending SOS...');
  try {
    const sosRes = await axios.post(`${BASE_URL}/sos`, {
      latitude: 14.5,
      longitude: 121.0,
      message: "Test Emergency via Proxy"
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ SOS Success:', sosRes.data);
  } catch (e: any) {
    console.error('❌ SOS Failed:', e.message);
     if (e.response) {
        console.log('Status:', e.response.status);
        console.log('FULL ERROR BODY:', JSON.stringify(e.response.data, null, 2));
    }
  }
}

main();
