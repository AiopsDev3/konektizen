-- CreateTable
CREATE TABLE "reporters" (
    "id" SERIAL NOT NULL,
    "full_name" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "email" TEXT,
    "username" TEXT,
    "password_hash" TEXT,
    "sex" TEXT,
    "birthday" TIMESTAMP(3),
    "age" INTEGER,
    "residential_address" TEXT,
    "municipality" TEXT,
    "province" TEXT,
    "region" TEXT,
    "role" TEXT NOT NULL DEFAULT 'CITIZEN',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "reporters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Report" (
    "id" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "city" TEXT NOT NULL,
    "address" TEXT,
    "mediaUrls" TEXT NOT NULL DEFAULT '',
    "mediaTypes" TEXT NOT NULL DEFAULT '',
    "reporterLatitude" DOUBLE PRECISION,
    "reporterLongitude" DOUBLE PRECISION,
    "status" TEXT NOT NULL DEFAULT 'submitted',
    "resolvedAt" TIMESTAMP(3),
    "resolutionNote" TEXT,
    "resolvedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "reporterId" INTEGER NOT NULL,

    CONSTRAINT "Report_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reporter_sos_events" (
    "id" SERIAL NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "message" TEXT,
    "status" TEXT NOT NULL DEFAULT 'Active',
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reporter_id" INTEGER NOT NULL,

    CONSTRAINT "reporter_sos_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "reporters_phone_number_key" ON "reporters"("phone_number");

-- CreateIndex
CREATE UNIQUE INDEX "reporters_email_key" ON "reporters"("email");

-- CreateIndex
CREATE UNIQUE INDEX "reporters_username_key" ON "reporters"("username");

-- AddForeignKey
ALTER TABLE "Report" ADD CONSTRAINT "Report_reporterId_fkey" FOREIGN KEY ("reporterId") REFERENCES "reporters"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reporter_sos_events" ADD CONSTRAINT "reporter_sos_events_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "reporters"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
