import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function deleteAdminAccounts() {
  try {
    // Find admin users first
    const adminUsers = await prisma.user.findMany({
      where: {
        OR: [
          { email: { contains: 'admin' } },
          { fullName: { contains: 'admin' } },
        ],
      },
    });

    const adminIds = adminUsers.map(u => u.id);
    console.log(`Found ${adminIds.length} admin account(s) to delete`);

    // Delete related data first
    await prisma.report.deleteMany({
      where: { userId: { in: adminIds } },
    });

    await prisma.sOSAlert.deleteMany({
      where: { userId: { in: adminIds } },
    });

    // Now delete the users
    const result = await prisma.user.deleteMany({
      where: { id: { in: adminIds } },
    });

    console.log(`✅ Deleted ${result.count} admin account(s) and their data`);
  } catch (error) {
    console.error('❌ Error deleting admin accounts:', error);
  } finally {
    await prisma.$disconnect();
  }
}

deleteAdminAccounts();
