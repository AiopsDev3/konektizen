import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting report seeding...');

  // 1. Find the admin user (or any user) to link these reports to
  // If no user exists, create a dummy one
  let user = await prisma.user.findFirst({
    where: { email: 'admin@konektizen.com' }
  });

  if (!user) {
    console.log('⚠️ Admin user not found. Creating a temporary user for seeding...');
    user = await prisma.user.create({
      data: {
        email: 'seeder@konektizen.com',
        password: 'password123',
        fullName: 'Seeder Bot',
        role: 'CITIZEN'
      }
    });
  }

  const userId = user.id;
  const now = new Date();

  // 2. Define sample reports (mixed categories, severities, locations in Metro Manila)
  const reports = [
    {
      category: 'Fire',
      severity: 'High',
      description: 'Malaking sunog sa palengke! Kailangan ng bumbero agad!',
      city: 'Quezon City',
      address: 'Commonwealth Market, Quezon City',
      latitude: 14.7001,
      longitude: 121.0800,
      status: 'submitted',
      mediaUrls: '["https://placehold.co/600x400/orange/white?text=Fire"]', // Dummy image
      mediaTypes: '["image"]',
      userId
    },
    {
      category: 'Flood',
      severity: 'Medium',
      description: 'Tumaas na ang baha dahil sa ulan. Hindi na makadaan ang mga sasakyan.',
      city: 'Manila',
      address: 'España Blvd, Sampaloc, Manila',
      latitude: 14.6091,
      longitude: 120.9890,
      status: 'submitted',
      mediaUrls: '["https://placehold.co/600x400/blue/white?text=Flood"]',
      mediaTypes: '["image"]',
      userId
    },
    {
      category: 'Waste',
      severity: 'Low',
      description: 'Tambak na basura sa kanto, nangangamoy na.',
      city: 'Caloocan',
      address: 'Monumento Circle, Caloocan',
      latitude: 14.6537,
      longitude: 120.9822,
      status: 'submitted',
      mediaUrls: '["https://placehold.co/600x400/brown/white?text=Garbage"]',
      mediaTypes: '["image"]',
      userId
    },
    {
      category: 'Traffic',
      severity: 'Medium',
      description: 'Complete standstill traffic sa EDSA Northbound due to accident.',
      city: 'Mandaluyong',
      address: 'EDSA near Shaw Blvd',
      latitude: 14.5815,
      longitude: 121.0532,
      status: 'submitted',
      mediaUrls: '["https://placehold.co/600x400/red/white?text=Traffic"]',
      mediaTypes: '["image"]',
      userId
    },
    {
      category: 'Infrastructure',
      severity: 'Low',
      description: 'Sirang poste ng ilaw, delikado pag gabi.',
      city: 'Makati',
      address: 'Ayala Ave, Makati',
      latitude: 14.5547,
      longitude: 121.0244,
      status: 'submitted',
      mediaUrls: '',
      mediaTypes: '',
      userId
    },
    {
      category: 'Medical',
      severity: 'Critical',
      description: 'Motorcycle accident involved 2 riders. Need ambulance ASAP.',
      city: 'Taguig',
      address: 'C5 Road, Taguig',
      latitude: 14.5300,
      longitude: 121.0500,
      status: 'submitted',
      mediaUrls: '["https://placehold.co/600x400/red/white?text=Accident"]',
      mediaTypes: '["image"]',
      userId
    },
    {
      category: 'Noise',
      severity: 'Low',
      description: 'Sobrang ingay ng karaoke ng kapitbahay lagpas 12am na.',
      city: 'Pasig',
      address: 'Ortigas Extension, Pasig',
      latitude: 14.5800,
      longitude: 121.0800,
      status: 'resolved', // Testing resolved status
      resolvedAt: now,
      resolvedBy: 'Admin',
      resolutionNote: 'Police visited the area.',
      mediaUrls: '',
      mediaTypes: '',
      userId
    },
    {
      category: 'Animal Control',
      severity: 'Medium',
      description: 'Stray dogs chasing pedestrians near the school.',
      city: 'Marikina',
      address: 'Riverbanks, Marikina',
      latitude: 14.6300,
      longitude: 121.0800,
      status: 'submitted',
      mediaUrls: '',
      mediaTypes: '',
      userId
    },
    {
      category: 'Theft',
      severity: 'High',
      description: 'Snatching incident reported near the train station.',
      city: 'Pasay',
      address: 'Taft Avenue, Pasay',
      latitude: 14.5400,
      longitude: 121.0000,
      status: 'submitted',
      mediaUrls: '',
      mediaTypes: '',
      userId
    },
    {
      category: 'Fire',
      severity: 'Critical',
      description: 'Grass fire spreading near residential area.',
      city: 'Valenzuela',
      address: 'MacArthur Highway, Valenzuela',
      latitude: 14.6900,
      longitude: 120.9700,
      status: 'submitted',
      mediaUrls: '["https://placehold.co/600x400/orange/white?text=Fire2"]',
      mediaTypes: '["image"]',
      userId
    }
  ];

  console.log(`📝 Inserting ${reports.length} sample reports...`);

  for (const report of reports) {
    await prisma.report.create({ data: report });
  }

  console.log('✅ Seeding complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
