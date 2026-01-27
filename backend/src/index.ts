import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import * as dotenv from 'dotenv';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import axios from 'axios';

import { WebhookService } from './services/webhook_service';

dotenv.config();

// Default to AIOPSYS if set, otherwise fallback to old AITERRA or local
const AIOPSYS_API_URL = process.env.AIOPSYS_API_URL || process.env.AITERRA_API_URL || "http://localhost:5001";


const app = express();
const prisma = new PrismaClient();
const PORT = 3000;
const SECRET_KEY = process.env.JWT_SECRET || "konektizen_super_secret_key"; // Use env var in production


app.use(cors({
  origin: '*', // Allow all origins for mobile app
  allowedHeaders: ['Content-Type', 'Authorization', 'Bypass-Tunnel-Reminder'] 
}));
app.use(express.json());

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, '../public/uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, '../public/uploads')));

// Multer storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  },
});

const upload = multer({ storage });

// --- Middleware ---
const authenticateToken = (req: any, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    res.sendStatus(401);
    return;
  }

  jwt.verify(token, SECRET_KEY, (err: any, user: any) => {
    if (err) {
      res.sendStatus(403);
      return;
    }
    req.user = user;
    next();
  });
};

// --- Auth Routes ---

// Register
app.post('/api/auth/register', async (req, res) => {
  const { email, password, fullName, phoneNumber, role } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        fullName,
        phoneNumber: phoneNumber || null,
        role: role || 'CITIZEN', // Default to CITIZEN
      },
    });
    // @ts-ignore
    delete user.password;
    res.json(user);
  } catch (e: any) {
    console.error('Registration Error:', e);
    if (e.code === 'P2002') {
      return res.status(400).json({ error: 'Email already exists' });
    }
    res.status(400).json({ error: e.message || 'User already exists or invalid data' });
  }
});

// Login
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return res.status(400).json({ error: 'User not found' });

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(400).json({ error: 'Invalid password' });

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, SECRET_KEY, { expiresIn: '1h' });
    res.json({ 
      token, 
      user: { 
        id: user.id, 
        email: user.email, 
        fullName: user.fullName, 
        role: user.role, 
        phoneNumber: user.phoneNumber,
        isVerified: user.isVerified,
        verificationStatus: user.verificationStatus,
        phoneVerified: user.phoneVerified // Ensure this is returned
      } 
    });
  } catch (e) {
    res.status(500).json({ error: 'Internal error' });
  }
});

// Phone Registration (Strict Create)
app.post('/api/auth/phone/register', async (req, res) => {
  const { firebaseUid, phoneNumber } = req.body;

  if (!firebaseUid || !phoneNumber) {
    return res.status(400).json({ error: 'Firebase UID and phone number required' });
  }

  try {
    // Check if user exists
    const existing = await prisma.user.findFirst({
      where: {
        OR: [{ firebaseUid }, { phoneNumber }],
      },
    });

    if (existing) {
      return res.status(409).json({ error: 'Number already registered. Please log in.' });
    }

    // Create new user (Strict)
    const user = await prisma.user.create({
      data: {
        firebaseUid,
        phoneNumber,
        email: null,
        fullName: "", 
        password: '',
        role: 'CITIZEN',
        phoneVerified: true, // Auto-verify for phone register
      },
    });

    // Generate Token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      SECRET_KEY,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
        role: user.role,
        isVerified: user.isVerified,
        verificationStatus: user.verificationStatus,
        phoneVerified: true // Explicitly true
      },
    });

  } catch (e) {
    console.error('Phone register error:', e);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Phone Login (Strict Check via Phone/UID)
app.post('/api/auth/phone/login', async (req, res) => {
  const { firebaseUid, phoneNumber } = req.body;

  if (!firebaseUid || !phoneNumber) {
    return res.status(400).json({ error: 'Data required' });
  }

  try {
    // Check if user exists
    let user = await prisma.user.findFirst({
      where: {
        OR: [{ firebaseUid }, { phoneNumber }],
      },
    });

    if (!user) {
      return res.status(404).json({ error: 'Account not found. Please register.' });
    }

    // If found by phone but missing UID, link it
    if (!user.firebaseUid) {
       user = await prisma.user.update({
        where: { id: user.id },
        data: { firebaseUid, phoneVerified: true }, // Ensure verified
      });
    } else if (!user.phoneVerified) {
       // If exists but not marked verified, mark it now since they have the phone credentials
       user = await prisma.user.update({
        where: { id: user.id },
        data: { phoneVerified: true },
      });
    }

    // Generate Token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      SECRET_KEY,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
        role: user.role,
        isVerified: user.isVerified,
        verificationStatus: user.verificationStatus,
        phoneVerified: true
      },
    });
  } catch (e: any) {
    console.error('Phone login error:', e);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Complete Phone Profile (After Registration)
app.post('/api/auth/phone/complete-profile', authenticateToken, async (req: any, res) => {
  const { fullName, password } = req.body;
  
  if (!fullName) {
    return res.status(400).json({ error: 'Full name is required' });
  }

  try {
    const updateData: any = { fullName };
    
    // Hash password if provided
    if (password && password.trim() !== '') {
      updateData.password = await bcrypt.hash(password, 10);
    }
    
    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: updateData
    });

    res.json({ success: true, user: { id: user.id, fullName: user.fullName } });
  } catch (e: any) {
    console.error('Complete Profile Error:', e);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// Get current user
app.get('/api/auth/me', authenticateToken, async (req: any, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
        phoneVerified: true,
        role: true,
        isVerified: true,
        verificationStatus: true,
        firebaseUid: true,
        facebookId: true
      }
    });
    
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Infer Auth Provider
    let authProvider = 'EMAIL';
    if (user.firebaseUid) authProvider = 'PHONE';
    else if (user.facebookId) authProvider = 'FACEBOOK';

    res.json({ ...user, authProvider });
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Facebook Login
app.post('/api/auth/facebook', async (req, res) => {
  const { accessToken } = req.body;
  
  if (!accessToken) {
    return res.status(400).json({ error: 'Access token required' });
  }

  try {
    // 1. Verify Token with Facebook Graph API
    // We strictly use axios to call Facebook's endpoint
    const fbRes = await axios.get(`https://graph.facebook.com/me?fields=id,name,email&access_token=${accessToken}`);
    
    if (fbRes.status !== 200) {
      return res.status(400).json({ error: 'Invalid Facebook Token' });
    }

    const { id: fbId, name, email } = fbRes.data;
    
    // 2. Find or Create User
    let user = await prisma.user.findFirst({
      where: {
        OR: [
          { facebookId: fbId },
          { email: email || `fb_${fbId}@facebook.placeholder` } // Handle no-email cases
        ]
      }
    });

    if (!user) {
      // Create new user
      user = await prisma.user.create({
        data: {
          email: email || `fb_${fbId}@facebook.placeholder`,
          password: await bcrypt.hash(`fb_${fbId}_secret`, 10), // Dummy password
          fullName: name,
          facebookId: fbId,
          role: 'CITIZEN'
        }
      });
    } else {
      // Link FB ID if not linked
      if (!user.facebookId) {
        user = await prisma.user.update({
          where: { id: user.id },
          data: { facebookId: fbId }
        });
      }
    }

    // 3. Issue Token
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role, fullName: user.fullName }, SECRET_KEY, { expiresIn: '7d' });
    res.json({ token, user: { id: user.id, fullName: user.fullName, email: user.email, role: user.role } });

  } catch (e: any) {
    console.error('Facebook Auth Error:', e.message);
    res.status(500).json({ error: 'Facebook Authentication Failed' });
  }
});

// --- LLM Routes ---

import { analyzeIncidentReport, checkLLMHealth } from './llm_service';

// Analyze incident description
app.post('/api/llm/analyze', async (req, res) => {
  const { description } = req.body;
  
  if (!description || typeof description !== 'string') {
    return res.status(400).json({ error: 'Description is required and must be a string' });
  }

  try {
    const analysis = await analyzeIncidentReport(description);
    res.json(analysis);
  } catch (error: any) {
    console.error('LLM analysis error:', error);
    res.status(500).json({ error: 'Failed to analyze incident report', message: error.message });
  }
});

// LLM health check
app.get('/api/llm/health', async (req, res) => {
  try {
    const health = await checkLLMHealth();
    res.json(health);
  } catch (error: any) {
    res.status(500).json({ error: 'Health check failed', message: error.message });
  }
});


// --- Verification Routes ---
import { verifyIdentityDocumentLocal } from './ocr_service';

// 1. Upload ID Image & Address Info
app.post('/api/verification/upload', authenticateToken, upload.single('idImage'), async (req: any, res) => {
  try {
    const { city, barangay, addressDetail, sex, birthday, age, phoneNumber } = req.body;

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    // Construct file URL
    const fileUrl = `/uploads/${req.file.filename}`;

    // Update User with ID Image URL and Address + Personal Info
    await prisma.user.update({
      where: { id: req.user.id },
      data: {
        idImageUrl: fileUrl,
        // Save Address Data
        city: city || undefined,
        barangay: barangay || undefined,
        addressDetail: addressDetail || undefined,
        // Save Personal Info
        sex: sex || undefined,
        birthday: birthday ? new Date(birthday) : undefined,
        age: age ? parseInt(age.toString()) : undefined,
        phoneNumber: phoneNumber || undefined,
        phoneVerified: req.body.phoneVerified === 'true', // Parse string "true"
        verificationStatus: 'PENDING' // Set pending until analysis
      }
    });

    res.json({ url: fileUrl, message: 'ID and address info uploaded successfully' });
  } catch (e) {
    console.error('Upload Error:', e);
    res.status(500).json({ error: 'Failed to upload ID and address info' });
  }
});

// 2. Perform AI Verification
app.post('/api/verification/analyze', authenticateToken, async (req: any, res) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user || !user.idImageUrl) {
      return res.status(400).json({ error: 'No ID image found for user' });
    }

    // Get absolute path of the uploaded file
    const imagePath = path.join(__dirname, '../public', user.idImageUrl);
    
    if (!fs.existsSync(imagePath)) {
      return res.status(404).json({ error: 'ID image file missing on server' });
    }

    // Call Local Tesseract OCR
      const verificationResult = await verifyIdentityDocumentLocal(
        imagePath, 
        user.fullName,
        (user as any).city || "", // Cast to any to avoid stale type errors
        (user as any).barangay || ""
      );
    
    // Update User Status based on result
    const newStatus = verificationResult.isVerified ? 'VERIFIED' : 'REJECTED'; // Default to PENDING if failed
    
    await prisma.user.update({
      where: { id: user.id },
      data: {
        isVerified: verificationResult.isVerified,
        verificationStatus: newStatus,
        verificationNote: verificationResult.reasoning
      }
    });

    res.json({
      success: true,
      result: verificationResult
    });

  } catch (e: any) {
    console.error('Verification Error:', e);
    res.status(500).json({ error: 'Verification analysis failed', details: e.message });
  }
});

// 3. Verify Phone (KYC Step)
app.post('/api/kyc/verify-phone', authenticateToken, async (req: any, res) => {
  const { phoneNumber } = req.body;

  if (!phoneNumber) {
    return res.status(400).json({ error: 'Phone number required' });
  }

  try {
    // Check conflicts (is this phone number already used by ANOTHER verified user?)
    const existing = await prisma.user.findFirst({
      where: {
        phoneNumber,
        phoneVerified: true,
        NOT: { id: req.user.id }
      }
    });

    if (existing) {
       return res.status(409).json({ error: 'Phone number already linked to another verified account.' });
    }

    await prisma.user.update({
      where: { id: req.user.id },
      data: {
        phoneNumber,
        phoneVerified: true
      }
    });

    res.json({ success: true, message: 'Phone number verified' });
  } catch (e) {
    console.error('Phone Verify Error:', e);
    res.status(500).json({ error: 'Failed to verify phone number' });
  }
});

// 3. Verify Phone (KYC Step)
app.post('/api/kyc/verify-phone', authenticateToken, async (req: any, res) => {
  const { phoneNumber } = req.body;

  if (!phoneNumber) {
    return res.status(400).json({ error: 'Phone number required' });
  }

  try {
    // Check conflicts (is this phone number already used by ANOTHER verified user?)
    const existing = await prisma.user.findFirst({
      where: {
        phoneNumber,
        phoneVerified: true,
        NOT: { id: req.user.id }
      }
    });

    if (existing) {
       return res.status(409).json({ error: 'Phone number already linked to another verified account.' });
    }

    await prisma.user.update({
      where: { id: req.user.id },
      data: {
        phoneNumber,
        phoneVerified: true
      }
    });

    res.json({ success: true, message: 'Phone number verified' });
  } catch (e) {
    console.error('Phone Verify Error:', e);
    res.status(500).json({ error: 'Failed to verify phone number' });
  }
});


// --- Upload Routes ---
app.post('/api/upload', upload.single('file'), (req: Request, res: Response) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  // Use relative path for storage, client will prepend base URL
  const fileUrl = `/uploads/${req.file.filename}`;
  res.json({ url: fileUrl });
});

// --- Case Routes ---

// Get My Cases
app.get('/api/cases', authenticateToken, async (req: any, res) => {
  try {
    const cases = await prisma.report.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' }
    });
    res.json(cases);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch cases' });
  }
});

// Submit Case
app.post('/api/cases', authenticateToken, async (req: any, res) => {
  const { category, severity, description, city, address, latitude, longitude, mediaUrls, mediaTypes, reporterLatitude, reporterLongitude } = req.body;
  
  console.log('=== Submitting case ===');
  console.log('Request body:', req.body);
  console.log('User:', req.user.id);
  
  try {
    const report = await prisma.report.create({
      data: {
        category,
        severity,
        description,
        city: city || 'Unknown',
        address: address || null,
        latitude: latitude || null,
        longitude: longitude || null,
        mediaUrls: Array.isArray(mediaUrls) ? mediaUrls.join(',') : (mediaUrls || ''),
        mediaTypes: Array.isArray(mediaTypes) ? mediaTypes.join(',') : (mediaTypes || ''),
        reporterLatitude: reporterLatitude || null,
        reporterLongitude: reporterLongitude || null,
        userId: req.user.id
      }
    });
    
    console.log('Report created successfully:', report.id);


    // --- AIOPSYS Integration: Forward Report ---
    try {
      console.log(`[AIOPSYS] Queuing report forward to: ${AIOPSYS_API_URL}/api/citizen/reports`);
      
      WebhookService.send(`${AIOPSYS_API_URL}/api/citizen/reports`, {
        reportId: report.id,
        category: category.toUpperCase(),
        description: description,
        latitude: latitude || 0,
        longitude: longitude || 0,
        address: address || "Unknown",
        status: 'submitted',
        timestamp: new Date().toISOString(),
        // Media URLs (ensure absolute path for external system)
        mediaUrls: (mediaUrls || []).map((url: string) => {
           if (url.startsWith('http')) return url;
           // Use LAN IP for local testing
           return `http://172.16.0.101:3000${url.startsWith('/') ? '' : '/'}${url}`;
        }),
        reporterInfo: {
          name: req.user.fullName || "Anonymous",
          phone: req.user.phoneNumber || "",
          id: req.user.id
        }
      });
      
    } catch (e: any) {
      console.error('[AIOPSYS] Error queuing report:', e.message);
    }

    res.status(201).json(report);
  } catch (e: any) {
    console.error('Failed to create report:', e);
    res.status(500).json({ error: 'Failed to create report', details: e?.message || 'Unknown error' });
  }
});

// SOS Alert
app.post('/api/sos', authenticateToken, async (req: any, res) => {
  const { latitude, longitude } = req.body;
  
  if (!latitude || !longitude) {
     return res.status(400).json({ error: 'Location required for SOS' });
  }

  try {
    const sos = await prisma.sOSAlert.create({
      data: {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        userId: req.user.id
      }
    });

    console.log(`[SOS] Emergency Alert from user ${req.user.id} at ${latitude},${longitude}`);


    // --- AIOPSYS Integration: Forward SOS (Priority) ---
    try {
      console.log(`[AIOPSYS] Queuing SOS Alert to: ${AIOPSYS_API_URL}/api/citizen/sos`);
      
      // Construct the Responder Link
      // We point to our local 'responder.html' which users can open
      // In production this would be a real domain
      const responderLink = `http://172.16.0.101:5000/responder?room=sos-${sos.id}&auto_join=true`;

      WebhookService.send(`${AIOPSYS_API_URL}/api/citizen/sos`, {
        event: "SOS_ALERT",
        alertId: sos.id,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        reporterInfo: {
          name: req.user.fullName || "Anonymous",
          phone: req.user.phoneNumber || "",
          id: req.user.id
        },
        timestamp: new Date().toISOString(),
        // Vital for the "Pop Up & Call" feature
        action_link: responderLink 
      });

    } catch (err: any) {
      console.error('[AIOPSYS] Failed to queue SOS:', err.message);
    }

    res.json({ success: true, alertId: sos.id });
  } catch (e: any) {
    console.error('SOS Error:', e);
    res.status(500).json({ error: 'Failed to send SOS' });
  }
});

// Middleware: Require Admin Role
const requireAdmin = (req: any, res: Response, next: NextFunction) => {
  if (req.user.role !== 'ADMIN') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

// Update Report (citizen can edit own, admin can edit any)
app.patch('/api/cases/:id', authenticateToken, async (req: any, res) => {
  const { id } = req.params;
  const { description, latitude, longitude, city, address, mediaUrls, mediaTypes, reporterLatitude, reporterLongitude } = req.body;
  
  try {
    // Check ownership or admin
    const existing = await prisma.report.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    if (existing.userId !== req.user.id && req.user.role !== 'ADMIN') {
      return res.status(403).json({ error: 'Not authorized to edit this report' });
    }
    
    const updateData: any = {};
    if (description) updateData.description = description;
    if (latitude !== undefined) updateData.latitude = latitude;
    if (longitude !== undefined) updateData.longitude = longitude;
    if (city) updateData.city = city;
    if (address !== undefined) updateData.address = address;
    if (mediaUrls) updateData.mediaUrls = mediaUrls.join(',');
    if (mediaTypes) updateData.mediaTypes = mediaTypes.join(',');
    if (reporterLatitude !== undefined) updateData.reporterLatitude = reporterLatitude;
    if (reporterLongitude !== undefined) updateData.reporterLongitude = reporterLongitude;
    
    const updated = await prisma.report.update({
      where: { id },
      data: updateData
    });
    
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: 'Failed to update report' });
  }
});

// Delete/Withdraw Report (citizen can delete own submitted reports)
app.delete('/api/cases/:id', authenticateToken, async (req: any, res) => {
  const { id } = req.params;
  
  try {
    // Check if report exists
    const existing = await prisma.report.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    // Only allow deletion if:
    // 1. User owns the report AND
    // 2. Report status is still 'submitted' (not yet processed)
    if (existing.userId !== req.user.id) {
      return res.status(403).json({ error: 'Not authorized to delete this report' });
    }
    
    if (existing.status !== 'submitted') {
      return res.status(400).json({ error: 'Cannot delete report that is already being processed' });
    }
    
    // Delete the report
    await prisma.report.delete({ where: { id } });
    
    res.status(200).json({ message: 'Report deleted successfully' });
  } catch (e) {
    console.error('Delete report error:', e);
    res.status(500).json({ error: 'Failed to delete report' });
  }
});

// Admin: Resolve Report
app.post('/api/cases/:id/resolve', authenticateToken, requireAdmin, async (req: any, res) => {
  const { id } = req.params;
  const { resolutionNote } = req.body;
  
  try {
    const resolved = await prisma.report.update({
      where: { id },
      data: {
        status: 'resolved',
        resolvedAt: new Date(),
        resolutionNote: resolutionNote || '',
        resolvedBy: req.user.id
      }
    });
    
    res.json(resolved);
  } catch (e) {
    res.status(500).json({ error: 'Failed to resolve report' });
  }
});


// --- AIOPSYS Integrations (Inbound) ---

// Receive Status Update from Command Center
app.post('/api/integrations/aiopsys/status-update', WebhookService.validateApiKey, async (req: any, res) => {
  const { reportId, status, responderEta, note } = req.body;
  
  if (!reportId || !status) {
    return res.status(400).json({ error: 'reportId and status are required' });
  }

  try {
    console.log(`[AIOPSYS] Received Status Update for ${reportId}: ${status}`);
    
    // Check if report exists
    const report = await prisma.report.findUnique({ where: { id: reportId } });
    if (!report) {
       return res.status(404).json({ error: 'Report not found' });
    }

    // Update the report
    const updateData: any = { 
      status: status.toLowerCase() 
    };
    
    // Append notes if provided
    if (note || responderEta) {
      const newNote = `[Command Center]: ${note || ''} ${responderEta ? '(ETA: ' + responderEta + ')' : ''}`.trim();
      updateData.resolutionNote = report.resolutionNote 
        ? report.resolutionNote + '\n' + newNote
        : newNote;
    }
    
    // If status is 'resolved', mark timestamp
    if (status.toLowerCase() === 'resolved') {
      updateData.resolvedAt = new Date();
      updateData.resolvedBy = 'AIOPSYS_COMMAND_CENTER';
    }

    await prisma.report.update({
      where: { id: reportId },
      data: updateData
    });

    res.json({ success: true, message: 'Status updated successfully' });
  } catch (e: any) {
    console.error('[AIOPSYS] Status Update Error:', e);
    res.status(500).json({ error: 'Internal processing error' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
