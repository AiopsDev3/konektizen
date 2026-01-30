import axios from 'axios';

const BASE_URL = 'http://172.16.0.101:3000/api';

async function main() {
  console.log('--- Debugging C3 API Error ---');
  // Use a highly random email/phone to ensure uniqueness
  const uniqueId = Date.now().toString();
  const email = `debug_${uniqueId}@test.com`;
  const phone = `09${Math.floor(Math.random() * 1000000000)}`;
  
  console.log(`Attempting register with: ${email} / ${phone}`);

  try {
    const res = await axios.post(`${BASE_URL}/auth/register`, {
      email,
      password: 'password123',
      fullName: `Debug User ${uniqueId}`,
      phoneNumber: phone
    });
    console.log('✅ Success! (User created)');
    console.log('Response:', JSON.stringify(res.data, null, 2));
  } catch (e: any) {
    console.log('❌ Failed!');
    if (e.response) {
       console.log('Status:', e.response.status);
       console.log('FULL ERROR BODY:');
       console.log(JSON.stringify(e.response.data, null, 2));
    } else {
       console.error('Error:', e.message);
    }
  }
}

main();
