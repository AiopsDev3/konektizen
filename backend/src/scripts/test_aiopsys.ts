
import axios from 'axios';

const API_URL = 'http://localhost:3000/api/integrations/aiopsys/status-update';
const API_KEY = 'konektizen-aiopsys-secret-key';

async function testStatusUpdate() {
  try {
    console.log('Testing Status Update...');
    const response = await axios.post(API_URL, {
      reportId: 'test-report-id', // Assuming this ID won't match anything but should invoke the endpoint
      status: 'DISPATCHED',
      note: 'Test note from script'
    }, {
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': API_KEY
      }
    });
    console.log('Success:', response.status, response.data);
  } catch (error: any) {
    if (error.response) {
      console.log('Response Error:', error.response.status, error.response.data);
    } else {
      console.log('Error:', error.message);
    }
  }
}

testStatusUpdate();
