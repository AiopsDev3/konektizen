import axios from 'axios';

const BASE_URL = 'http://172.16.0.101:3000/api';

async function main() {
  console.log('--- Testing Duplicate Registration ---');
  const email = 'duplicate_test@example.com';
  
  // 1. Register first time (Should Success)
  try {
    await axios.post(`${BASE_URL}/auth/register`, {
      email,
      password: 'password123',
      fullName: 'Dup User',
      phoneNumber: `09${Math.floor(Math.random()*1000000000)}` // Random phone
    });
    console.log('1st Register: Success');
  } catch (e) {
    console.log('1st Register: Failed (Maybe already exists)');
  }

  // 2. Register second time (Should Fail)
  try {
    await axios.post(`${BASE_URL}/auth/register`, {
      email,
      password: 'password123',
      fullName: 'Dup User',
      phoneNumber: `09${Math.floor(Math.random()*1000000000)}` 
    });
    console.log('2nd Register: Unexpected Success');
  } catch (e: any) {
    console.log('2nd Register: Failed (Expected)');
    if (e.response) {
        console.log('Error Status:', e.response.status);
        console.log('Error Data:', JSON.stringify(e.response.data, null, 2));
    } else {
        console.log('Error:', e.message);
    }
  }
}

main();
