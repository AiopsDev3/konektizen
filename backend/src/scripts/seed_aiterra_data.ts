
import axios from 'axios';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();
const API_URL = 'http://localhost:3000/api';

// Sample Data
const REPORTS = [
  {
    category: 'FIRE',
    severity: 'high',
    description: 'Structure fire visible at 3rd floor of commercial building. Black smoke.',
    latitude: 14.6095,
    longitude: 121.0252, // Cubao area
    address: 'Aurora Blvd, Cubao, Quezon City',
    mediaUrls: ['http://172.16.0.75:3000/uploads/sample_fire.jpg'],
    mediaTypes: ['image'],
  },
  {
    category: 'TRAFFIC',
    severity: 'medium',
    description: 'Heavy congestion due to stalled truck blocking two lanes.',
    latitude: 14.5369,
    longitude: 121.0086, // Pasay
    address: 'EDSA, Pasay City',
    mediaUrls: [],
    mediaTypes: [],
  },
  {
    category: 'MEDICAL',
    severity: 'high',
    description: 'Motorcycle accident, rider conscious but injured.',
    latitude: 14.5995,
    longitude: 120.9842, // Manila
    address: 'España Blvd, Manila',
    mediaUrls: [],
    mediaTypes: [],
  },
  {
    category: 'FLOOD',
    severity: 'medium',
    description: 'Knee-deep flood water rendering road impassable for light vehicles.',
    latitude: 14.6178,
    longitude: 121.0040, // Sampaloc
    address: 'V. Mapa, Manila',
    mediaUrls: ['http://172.16.0.75:3000/uploads/sample_flood.jpg'],
    mediaTypes: ['image'],
  }
];

async function generateData() {
  console.log('=== Starting Data Generation ===');

  try {
    // 1. Login as Admin/User to get token (using seeded admin)
    // Note: Ensure your seed script created 'admin@konektizen.com' / 'password123'
    console.log('Logging in...');
    const loginRes = await axios.post(`${API_URL}/auth/login`, {
      email: 'admin@konektizen.com',
      password: 'password123'
    });

    const token = loginRes.data.token;
    console.log('Logged in successfully.');

    // 2. Submit Reports
    console.log(`Submitting ${REPORTS.length} reports...`);
    
    for (const report of REPORTS) {
      try {
        await axios.post(`${API_URL}/cases`, report, {
          headers: { Authorization: `Bearer ${token}` }
        });
        console.log(`[SUCCESS] Submitted: ${report.category} at ${report.address}`);
        // Small delay to ensure sequential processing/logs
        await new Promise(r => setTimeout(r, 1000));
      } catch (e: any) {
        console.error(`[FAILED] ${report.category}:`, e.message);
      }
    }

    console.log('=== Data Generation Complete ===');

  } catch (e: any) {
    console.error('Script Error:', e.message);
    if (e.response) {
      console.error('Response Data:', e.response.data);
    }
  } finally {
    await prisma.$disconnect();
  }
}

generateData();
