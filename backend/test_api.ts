import axios from 'axios';

async function main() {
  const url = 'http://172.16.0.140:5001/api/reporters';
  console.log(`Testing connectivity to ${url}...`);
  try {
    // Just try a GET or OPTIONS to see if it connects. POST might require data.
    // The user said it's for creating users, so likely POST.
    // Let's try to connect. Even 404/405/400 proves reachability.
    const res = await axios.get(url, { timeout: 5000 }).catch(e => e.response || e);
    
    if (res.status) {
      console.log(`Success! Reachable. Status: ${res.status}`);
    } else if (res.code) {
        console.error(`Connection failed: ${res.code}`);
    } else {
        console.log('Result:', res);
    }
  } catch (e) {
    console.error('Fatal Error:', e);
  }
}

main();
