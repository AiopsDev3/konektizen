import axios from 'axios';

const BASE_URL = 'http://172.16.0.101:3000/api';

async function main() {
  console.log('--- Debugging Login Flow ---');
  const uniqueId = Date.now().toString();
  const email = `login_debug_${uniqueId}@test.com`;
  const password = 'password123';
  const phone = `09${Math.floor(Math.random() * 1000000000)}`;
  
  // 1. Register
  console.log(`1. Registering: ${email} ...`);
  try {
    const regRes = await axios.post(`${BASE_URL}/auth/register`, {
      email,
      password,
      fullName: `Login Debugger ${uniqueId}`,
      phoneNumber: phone
    });
    console.log('✅ Registration 201 (Created)');
  } catch (e: any) {
    console.error('❌ Registration Failed:', e.message);
    if (e.response) console.error(JSON.stringify(e.response.data, null, 2));
    return;
  }

  // 2. Login Variant A: Standard Email
  console.log(`2A. Logging in with EMAIL: ${email} ...`);
  try {
    const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
      email,
      password
    });
    console.log('✅ Login (Email) Success');
  } catch (e: any) {
    console.log('❌ Login (Email) Failed:', e.response?.data?.message || e.message);
  }

  // 2B. Login Variant B: Username (derived from email)
  const derivedUsername = email.split('@')[0];
  console.log(`2B. Logging in with USERNAME: ${derivedUsername} ...`);
  try {
    // Note: Our Backend Proxy currently only accepts { email, password } in req.body
    // So we can't test this easily unless we change the backend first OR if we bypass proxy.
    // BUT, we can test if we send 'email' field but with the username value?
    // Let's try to hit C3 DIRECTLY? No, firewall.
    
    // We must modify backend to allow passing 'username' or adapt 'email' to 'username'.
    // Let's testing sending username in the 'email' field to our backend, hoping it passes it through?
    // Our backend: const { email, password } = req.body;
    // axios.post(..., { email, password })
    // So if we send { email: derivedUsername, password }, it sends { email: deriveUsername } to C3.
    
    const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
      email: derivedUsername,
      password
    });
    console.log('✅ Login (Username passed as Email) Success');
  } catch (e: any) {
      console.log('❌ Login (Username passed as Email) Failed:', e.response?.data?.message || e.message);
  }
}

main();
