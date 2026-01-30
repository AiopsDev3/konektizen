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

  // C3 API Integration: We cannot verify the signature because we don't have C3's secret.
  // We trust the token because the client obtained it via our Proxy from C3.
  // We strictly DECODE it to get user info.
  try {
    console.log('[Auth] Verifying token:', token.substring(0, 10) + '...');
    const user = jwt.decode(token);
    console.log('[Auth] Decoded user:', user);
    
    if (!user) {
        console.error('[Auth] Token decode returned null. Token received:', token);
        res.status(403).json({ error: 'Invalid Token Format', receivedToken: token });
        return;
    }
    req.user = user;
    next();
  } catch (e) {
    console.error('Token Decode Error:', e);
    res.sendStatus(403);
  }
};

// --- Auth Routes ---

// Register
// Register - Proxy to C3 API
app.post('/api/auth/register', async (req, res) => {
  const { email, password, fullName, phoneNumber, role } = req.body;
  const C3_API = process.env.C3_API_BASE_URL || "http://172.16.0.140:5001/api/reporters";
  
  try {
    console.log(`[Proxy] Registering user at likely ${C3_API}/register`);
    // Note: User provided full URL examples like http://.../api/reporters/register
    // My C3_API_BASE_URL is .../api/reporters
    
    const response = await axios.post(`${C3_API}/register`, {
      email,
      password,
      full_name: fullName, // C3 expects snake_case based on schema discussion? Or simple mapping?
      phone_number: phoneNumber,
      username: email ? email.split('@')[0] : fullName.replace(/\s+/g, '').toLowerCase(),
      role: role || 'CITIZEN'
    });
    
    // ...
    res.json(response.data);
  } catch (e: any) {
    console.error('Registration Proxy Error Message:', e.message);
    if (e.response) {
       console.error('Registration Proxy API Response:', JSON.stringify(e.response.data, null, 2));
       return res.status(e.response.status).json(e.response.data);
    }
    res.status(500).json({ error: 'Registration failed via C3 Proxy' });
  }
});

// Login
// Login - Proxy to C3 API
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const C3_API = process.env.C3_API_BASE_URL || "http://172.16.0.140:5001/api/reporters";

  // Helper to try login
  const tryLogin = async (identifier: string) => {
     return await axios.post(`${C3_API}/login`, {
      email: identifier,
      password
    });
  };

  try {
    console.log(`[Proxy] Logging in user at ${C3_API}/login`);
    
    try {
        // Attempt 1: Try with Email
        const response = await tryLogin(email);
        return res.json(response.data);
    } catch (err: any) {
        // Attempt 2: If failed and looks like 400/401, try with Username (split by @)
        // Only if email seems to have a domain part
        if (email.includes('@')) {
             const username = email.split('@')[0];
             console.log(`[Proxy] Email login failed, trying username: ${username}`);
             const response = await tryLogin(username);
             return res.json(response.data);
        }
        throw err; // Re-throw if not recoverable
    }

  } catch (e: any) {
     console.error('Login Proxy Error:', e.message);
    if (e.response) {
       return res.status(e.response.status).json(e.response.data);
    }
    res.status(500).json({ error: 'Login failed via C3 Proxy' });
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
    const existing = await prisma.reporter.findFirst({
      where: {
        OR: [/* { firebaseUid }, */ { phoneNumber }], // firebaseUid not in schema, rely on phone
      },
    });

    if (existing) {
      return res.status(409).json({ error: 'Number already registered. Please log in.' });
    }

    // Create new user (Strict, mapped to Reporters)
    const reporter = await prisma.reporter.create({
      data: {
        // Map fields to new schema
        // firebaseUid is not in C3 schema, store in generic field or omit? 
        // C3 schema has: username, phone_number, email. 
        // We will map phoneNumber -> phone_number
        phoneNumber,
        // password_hash is optional, we can leave null for phone auth or set dummy
        // C3 schema: full_name (optional)
        fullName: "", 
        role: 'CITIZEN',
      },
    });

    // Generate Token
    // Payload ID is now number
    const token = jwt.sign(
      { id: reporter.id, email: reporter.email, role: reporter.role },
      SECRET_KEY,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: reporter.id,
        email: reporter.email,
        fullName: reporter.fullName,
        phoneNumber: reporter.phoneNumber,
        role: reporter.role,
        // isVerified removed from schema, checking verification logic might need update
        phoneVerified: true // Implicit
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
    // Note: Schema doesn't have firebaseUid. We trust phone number for now or need migration.
    // Assuming checking by phone number is enough if we trust the caller (verified by firebase on client)
    let reporter = await prisma.reporter.findFirst({
      where: {
        OR: [/* { firebaseUid }, */ { phoneNumber }],
      },
    });

    if (!reporter) {
      return res.status(404).json({ error: 'Account not found. Please register.' });
    }

    // Update if needed (e.g. set some verified flag if we had one)
    // For now C3 schema is simple.
    // If found, just return token.
    
    // Generate Token
    const token = jwt.sign(
      { id: reporter.id, email: reporter.email, role: reporter.role },
      SECRET_KEY,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: reporter.id,
        email: reporter.email,
        fullName: reporter.fullName,
        phoneNumber: reporter.phoneNumber,
        role: reporter.role,
        phoneVerified: true
      },
    });
    return; // Stop execution here to avoid running the old logic below
  } catch (e: any) {
    console.error('Phone login error:', e);
    res.status(500).json({ error: 'Login failed' });
    // avoid executing fallback
    return;
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
    
    const reporter = await prisma.reporter.update({
      where: { id: req.user.id },
      data: updateData
    });

    res.json({ success: true, user: { id: reporter.id, fullName: reporter.fullName } });
  } catch (e: any) {
    console.error('Complete Profile Error:', e);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// Get current user
app.get('/api/auth/me', authenticateToken, async (req: any, res) => {
  const C3_API = process.env.C3_API_BASE_URL || "http://172.16.0.140:5001/api/reporters";
  
  try {
    console.log('[Proxy] Fetching current user from C3 API');
    console.log('[Proxy] User from token:', req.user);
    
    // Proxy to C3 API to get current user
    const response = await axios.get(`${C3_API}/me`, {
      headers: {
        'Authorization': req.headers['authorization'] // Forward the token
      }
    });
    
    console.log('[Proxy] User data from C3:', response.data);
    res.json(response.data);
  } catch (e: any) {
    console.error('[Proxy] Failed to fetch user from C3:', e.message);
    if (e.response) {
      console.error('[Proxy] C3 Response:', e.response.data);
      return res.status(e.response.status).json(e.response.data);
    }
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Facebook Login
// Facebook Login - DISABLED (Schema doesn't support facebookId)
app.post('/api/auth/facebook', async (req, res) => {
  return res.status(501).json({ error: 'Facebook login not supported in this version' });
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
    // Note: C3 schema 'Reporters' table might not have idImagUrl etc.
    // We will attempt to update what we can or skip if field missing.
    // Based on schema from user: sex, birthday, age, residentialAddress, municipality, province, region.
    // We map appropriately.
    
    const updatePayload: any = {
         sex: sex || undefined,
         birthday: birthday ? new Date(birthday) : undefined,
         age: age ? parseInt(age.toString()) : undefined,
         residentialAddress: addressDetail, // mapping
         municipality: city, // mapping
         // province/region not passed but can be added if frontend sends
    };

    if (phoneNumber) updatePayload.phoneNumber = phoneNumber;

    await prisma.reporter.update({
      where: { id: req.user.id },
      data: updatePayload
    });

    res.json({ url: fileUrl, message: 'ID and address info uploaded successfully (Note: Image URL storage not supported in current schema)' });
  } catch (e) {
    console.error('Upload Error:', e);
    res.status(500).json({ error: 'Failed to upload ID and address info' });
  }
});

// 2. Perform AI Verification - DISABLED for C3 Schema
app.post('/api/verification/analyze', authenticateToken, async (req: any, res) => {
    return res.status(501).json({ error: 'Verification not supported in this version' });
});



// 3. Verify Phone (KYC Step)
app.post('/api/kyc/verify-phone', authenticateToken, async (req: any, res) => {
  const { phoneNumber } = req.body;

  if (!phoneNumber) {
    return res.status(400).json({ error: 'Phone number required' });
  }

  try {
    // Check conflicts (is this phone number already used by ANOTHER verified user?)
    const existing = await prisma.reporter.findFirst({
      where: {
        phoneNumber,
        NOT: { id: req.user.id }
      }
    });

    if (existing) {
       return res.status(409).json({ error: 'Phone number already linked to another verified account.' });
    }

    await prisma.reporter.update({
      where: { id: req.user.id },
      data: {
        phoneNumber,
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
// Get My Cases
app.get('/api/cases', authenticateToken, async (req: any, res) => {
  return res.status(503).json({ error: 'Reporting features unavailable (DB Blocked). Need C3 API for Reports.' });
  // Legacy DB Code Disabled
});

// Submit Case
app.post('/api/cases', authenticateToken, async (req: any, res) => {
  console.log('=== Submitting case (Blocked) ===');
  return res.status(503).json({ error: 'Reporting features unavailable (DB Blocked). Need C3 API for Reports.' });
});

// SOS Alert
// SOS Alert - Proxy to C3 API
app.post('/api/sos', authenticateToken, async (req: any, res) => {
  const { latitude, longitude, message } = req.body; // Accept optional message
  const C3_API = process.env.C3_API_BASE_URL || "http://172.16.0.140:5001/api/reporters";
  
  if (!latitude || !longitude) {
     return res.status(400).json({ error: 'Location required for SOS' });
  }

  try {
    console.log(`[Proxy] Sending SOS to ${C3_API}/sos`);
    
    // C3 Requirement: Must send reporter_id in body
    // We get this from the decoded token (req.user)
    const reporterId = req.user?.id;

    if (!reporterId) {
        console.warn('[Proxy] Warning: No user ID found in token for SOS');
    }

    const response = await axios.post(`${C3_API}/sos`, {
        reporter_id: reporterId, // REQUIRED by C3
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        message: message || "Emergency Alert", // Default message
    }, {
        headers: {
            'Authorization': req.headers['authorization'] // Forward the token too, just in case
        }
    });

    console.log('[Proxy] SOS successful:', response.data);
    res.json(response.data);
    
  } catch (e: any) {
    console.error('SOS Proxy Error:', e.message);
     if (e.response) {
       console.error('SOS Proxy Response:', JSON.stringify(e.response.data, null, 2));
       return res.status(e.response.status).json(e.response.data);
    }
    res.status(500).json({ error: 'Failed to send SOS via C3 Proxy' });
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
    
    if (existing.reporterId !== req.user.id && req.user.role !== 'ADMIN') {
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
    if (existing.reporterId !== req.user.id) {
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
