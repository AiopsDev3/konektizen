import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  try {
    console.log('Attempting to connect to database...');
    await prisma.$connect();
    console.log('Successfully connected to database!');
    
    const count = await prisma.reporter.count();
    console.log(`Found ${count} reporters.`);
    
    await prisma.$disconnect();
    process.exit(0);
  } catch (e) {
    console.error('Failed to connect to database:', e);
    await prisma.$disconnect();
    process.exit(1);
  }
}

main();
