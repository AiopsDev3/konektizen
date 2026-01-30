import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const email = 'admin@konektizen.com';
  const password = 'password123';
  const fullName = 'Admin User';
  const phoneNumber = "00000000000"; // Dummy

  const hashedPassword = await bcrypt.hash(password, 10);

  const reporter = await prisma.reporter.upsert({
    where: { email },
    update: {},
    create: {
      email,
      password: hashedPassword,
      fullName,
      phoneNumber,
      role: 'ADMIN'
    },
  });

  console.log({ reporter });
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
